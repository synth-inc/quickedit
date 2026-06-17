#!/usr/bin/env python3
"""
Inspect what `bestLevenshteinSpan` would pick as the highlight span for
custom-dictionary terms across the last N transcripts.

Reads ~/Library/Application Support/Onit/transcription_history.sqlite
(copies it first to avoid any chance of contention with the running app),
runs the Swift `bestLevenshteinSpan` algorithm in Python, and writes an
HTML viewer with each transcript and its highlighted span.

Usage:
    python3 scripts/inspect_dictionary_spans.py
    python3 scripts/inspect_dictionary_spans.py --limit 500 --terms Lenardo Onit
"""

import argparse
import html
import os
import shutil
import sqlite3
import tempfile
import time
import webbrowser
from dataclasses import dataclass
from pathlib import Path

DEFAULT_DB = Path.home() / "Library/Application Support/Onit/transcription_history.sqlite"
DEFAULT_TERMS = ["Lenardo", "Onit"]


def normalize(s: str) -> str:
    """Match Swift CustomDictionaryRescorer.normalize: lowercase, alnum + whitespace, trim."""
    out = []
    for c in s.lower():
        if c.isalnum() or c.isspace():
            out.append(c)
    return "".join(out).strip()


def normalize_key(s: str) -> str:
    """Match Swift normalizeKey: lowercase, alnum only (no whitespace)."""
    return "".join(c for c in s.lower() if c.isalnum())


def levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    m, n = len(a), len(b)
    prev = list(range(n + 1))
    curr = [0] * (n + 1)
    for i in range(1, m + 1):
        curr[0] = i
        for j in range(1, n + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            curr[j] = min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
        prev, curr = curr, prev
    return prev[n]


def similarity(a: str, b: str) -> float:
    if a == b:
        return 1.0
    if not a or not b:
        return 0.0
    return 1.0 - levenshtein(a, b) / max(len(a), len(b))


@dataclass
class SpanMatch:
    span: str          # joined original-cased words
    start_word: int    # word index (in `words`) where the span starts
    end_word: int      # exclusive
    sim: float


def best_span(words: list[str], term: str) -> SpanMatch:
    """
    Port of Swift bestLevenshteinSpan: best 1-3 contiguous-word window by
    normalised Levenshtein similarity vs. spaceless-normalised term.
    """
    term_key = normalize_key(term)  # e.g. "Lenardo" -> "lenardo"
    best = SpanMatch(span=words[0] if words else term, start_word=0, end_word=1, sim=0.0)
    if not words:
        return best
    max_n = min(3, len(words))
    for n in range(1, max_n + 1):
        for i in range(0, len(words) - n + 1):
            slice_words = words[i:i + n]
            key = "".join(normalize_key(w) for w in slice_words)
            sim = similarity(key, term_key)
            if sim > best.sim:
                best = SpanMatch(
                    span=" ".join(slice_words),
                    start_word=i,
                    end_word=i + n,
                    sim=sim,
                )
    return best


@dataclass
class Row:
    rowid: int
    timestamp: str
    raw: str
    duration: float


def fetch_rows(db_path: Path, limit: int) -> list[Row]:
    src = db_path
    # Copy to temp so we never even read the live file. WAL means concurrent
    # readers are safe, but a copy is bulletproof.
    tmp_dir = Path(tempfile.mkdtemp(prefix="onit_dict_inspect_"))
    dst = tmp_dir / "transcription_history.sqlite"
    shutil.copy2(src, dst)
    # Copy WAL/SHM if present so we see the latest committed state.
    for suffix in ("-wal", "-shm"):
        side = src.with_suffix(src.suffix + suffix) if src.suffix else None
        # The Swift code names the file with .sqlite, so we look for .sqlite-wal etc.
        side = Path(str(src) + suffix)
        if side.exists():
            shutil.copy2(side, Path(str(dst) + suffix))

    conn = sqlite3.connect(f"file:{dst}?mode=ro", uri=True)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, timestamp, rawTranscription, audioDuration
            FROM transcription_history
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            (limit,),
        )
        rows = [
            Row(rowid=r[0], timestamp=str(r[1]), raw=r[2] or "", duration=float(r[3] or 0.0))
            for r in cur.fetchall()
        ]
        return rows
    finally:
        conn.close()
        # Leave tmp dir in place for debugging; it's tiny and self-cleaning on reboot.


def render_highlight(words: list[str], match: SpanMatch) -> str:
    """Build HTML for a sentence with the matched span wrapped in <mark>."""
    parts = []
    for idx, word in enumerate(words):
        if idx == match.start_word:
            parts.append('<mark>')
        parts.append(html.escape(word))
        if idx == match.end_word - 1:
            parts.append('</mark>')
        if idx != len(words) - 1:
            parts.append(' ')
    return "".join(parts)


def color_for(sim: float) -> str:
    if sim >= 0.85:
        return "#34c759"   # green — solid match
    if sim >= 0.65:
        return "#ffcc00"   # amber — plausible
    return "#ff3b30"       # red — likely no real occurrence


def render_html(results: dict[str, list[tuple[Row, SpanMatch, list[str]]]],
                total_scanned: int,
                min_sim: float) -> str:
    sections = []
    for term, items in results.items():
        rows_html = []
        for row, match, words in items:
            highlight = render_highlight(words, match)
            color = color_for(match.sim)
            rows_html.append(
                f'<tr>'
                f'<td class="sim" style="color:{color}">{match.sim:.2f}</td>'
                f'<td class="span">{html.escape(match.span)}</td>'
                f'<td class="sentence">{highlight}</td>'
                f'<td class="meta">'
                f'  <div>id {row.rowid}</div>'
                f'  <div>{html.escape(row.timestamp[:19])}</div>'
                f'  <div>{row.duration:.1f}s</div>'
                f'</td>'
                f'</tr>'
            )
        body = "\n".join(rows_html) if rows_html else (
            f'<tr><td colspan="4" class="empty">'
            f'No matches above sim {min_sim:.2f} for &ldquo;{html.escape(term)}&rdquo;.</td></tr>'
        )
        sections.append(
            f'<section>'
            f'  <h2>&ldquo;{html.escape(term)}&rdquo; — {len(items)} matches</h2>'
            f'  <table>'
            f'    <thead><tr>'
            f'      <th>sim</th><th>span</th><th>transcript</th><th>meta</th>'
            f'    </tr></thead>'
            f'    <tbody>{body}</tbody>'
            f'  </table>'
            f'</section>'
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dictionary span inspector</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      max-width: 1100px;
      margin: 24px auto;
      padding: 0 16px;
      line-height: 1.5;
    }}
    h1 {{ margin-bottom: 4px; }}
    .summary {{ color: #666; margin-bottom: 24px; font-size: 13px; }}
    section {{ margin: 32px 0; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th {{
      text-align: left;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #888;
      border-bottom: 1px solid #ccc;
      padding: 6px 8px;
    }}
    td {{
      padding: 8px;
      border-bottom: 1px solid rgba(128,128,128,0.15);
      vertical-align: top;
    }}
    td.sim {{ font-weight: 600; font-variant-numeric: tabular-nums; width: 50px; }}
    td.span {{ font-family: ui-monospace, monospace; width: 140px; word-break: break-word; }}
    td.sentence {{ width: auto; }}
    td.meta {{ width: 140px; font-size: 11px; color: #888; font-variant-numeric: tabular-nums; }}
    mark {{
      background: rgba(0, 122, 255, 0.25);
      color: inherit;
      padding: 0 2px;
      border-radius: 3px;
      font-weight: 600;
    }}
    .empty {{ color: #888; font-style: italic; padding: 16px; }}
    tr:hover td {{ background: rgba(128,128,128,0.06); }}
  </style>
</head>
<body>
  <h1>Dictionary span inspector</h1>
  <div class="summary">
    Scanned {total_scanned} transcripts. Showing matches with similarity ≥ {min_sim:.2f}.
    Green ≥ 0.85, amber ≥ 0.65, red below.
  </div>
  {''.join(sections)}
</body>
</html>
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--limit", type=int, default=500)
    ap.add_argument("--terms", nargs="+", default=DEFAULT_TERMS)
    ap.add_argument("--min-sim", type=float, default=0.5,
                    help="Hide transcripts whose best match is below this similarity.")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    if not args.db.exists():
        raise SystemExit(f"Database not found: {args.db}")

    t_load0 = time.perf_counter()
    rows = fetch_rows(args.db, args.limit)
    t_load_ms = (time.perf_counter() - t_load0) * 1000
    print(f"Loaded {len(rows)} transcripts in {t_load_ms:.1f} ms "
          f"({t_load_ms / max(len(rows), 1):.3f} ms/transcript)")

    results: dict[str, list[tuple[Row, SpanMatch, list[str]]]] = {t: [] for t in args.terms}
    per_call_us: list[float] = []
    t_scan0 = time.perf_counter()
    for row in rows:
        words = [w for w in row.raw.split() if w]
        if not words:
            continue
        for term in args.terms:
            t0 = time.perf_counter_ns()
            match = best_span(words, term)
            per_call_us.append((time.perf_counter_ns() - t0) / 1000.0)
            if match.sim >= args.min_sim:
                results[term].append((row, match, words))
    t_scan_ms = (time.perf_counter() - t_scan0) * 1000
    if per_call_us:
        per_call_us.sort()
        n = len(per_call_us)
        print(
            f"best_span: n={n} total={t_scan_ms:.1f} ms "
            f"mean={sum(per_call_us) / n:.1f} us "
            f"p50={per_call_us[n // 2]:.1f} us "
            f"p95={per_call_us[int(n * 0.95)]:.1f} us "
            f"max={per_call_us[-1]:.1f} us"
        )

    for term, items in results.items():
        items.sort(key=lambda t: t[1].sim, reverse=True)
        print(f"  {term}: {len(items)} matches above sim {args.min_sim}")

    out_path = Path(tempfile.gettempdir()) / "onit_dictionary_span_inspector.html"
    out_path.write_text(render_html(results, len(rows), args.min_sim))
    print(f"\nWrote {out_path}")

    if not args.no_open:
        webbrowser.open(f"file://{out_path}")


if __name__ == "__main__":
    main()
