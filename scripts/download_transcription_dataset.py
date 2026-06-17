#!/usr/bin/env python3
"""
Download transcription dataset audio files from Azure Blob Storage.

This script downloads audio.wav files from Azure and places them alongside
the existing metadata.json files in the datasets/transcription directory.

Usage:
    python3 scripts/download_transcription_dataset.py

Environment variables:
    AZURE_TRANSCRIPTION_SAS_KEY: SAS token for Azure (base64 encoded)

Or use command line:
    python3 scripts/download_transcription_dataset.py --sas-key "your-sas-key"
"""

import os
import sys
import json
import base64
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Azure configuration
AZURE_BLOB_BASE_URL = "https://syntheticco.blob.core.windows.net"
AZURE_CONTAINER = "transcription"

# Project paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATASETS_DIR = PROJECT_ROOT / "datasets" / "transcription"


def decode_sas_key(encoded_key: str) -> str:
    """Decode base64-encoded SAS key."""
    try:
        return base64.b64decode(encoded_key).decode('utf-8')
    except Exception:
        # If decoding fails, assume it's not encoded
        return encoded_key


def list_blobs(sas_key: str) -> list[dict]:
    """List all blobs in the transcription container."""
    url = f"{AZURE_BLOB_BASE_URL}/{AZURE_CONTAINER}?restype=container&comp=list&{sas_key}"

    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            content = response.read().decode('utf-8')

            # Parse XML response (simple parsing for blob names)
            blobs = []
            import re
            for match in re.finditer(r'<Name>([^<]+)</Name>', content):
                blob_name = match.group(1)
                blobs.append({"name": blob_name})

            return blobs
    except Exception as e:
        print(f"Error listing blobs: {e}")
        return []


def download_blob(sas_key: str, blob_name: str, local_path: Path) -> bool:
    """Download a single blob to local path."""
    url = f"{AZURE_BLOB_BASE_URL}/{AZURE_CONTAINER}/{blob_name}?{sas_key}"

    try:
        local_path.parent.mkdir(parents=True, exist_ok=True)

        with urllib.request.urlopen(url, timeout=60) as response:
            with open(local_path, 'wb') as f:
                f.write(response.read())

        return True
    except Exception as e:
        print(f"  Error downloading {blob_name}: {e}")
        return False


def sync_dataset(sas_key: str, dry_run: bool = False) -> tuple[int, int, int]:
    """
    Sync the dataset by downloading missing audio files.

    Returns: (downloaded, skipped, failed)
    """
    print(f"📂 Dataset directory: {DATASETS_DIR}")
    print(f"🌐 Azure container: {AZURE_CONTAINER}")
    print()

    # List all blobs
    print("📋 Listing blobs in Azure...")
    blobs = list_blobs(sas_key)

    if not blobs:
        print("❌ No blobs found or error listing blobs")
        return 0, 0, 0

    # Find audio files
    audio_blobs = [b for b in blobs if b["name"].endswith("/audio.wav")]
    print(f"   Found {len(audio_blobs)} audio files in Azure")
    print()

    # Check which ones we need to download
    to_download = []
    skipped = 0

    for blob in audio_blobs:
        # Extract case name from blob path (e.g., "case_1234567890/audio.wav" -> "case_1234567890")
        parts = blob["name"].split("/")
        if len(parts) != 2:
            continue

        case_name = parts[0]
        local_audio_path = DATASETS_DIR / case_name / "audio.wav"
        local_metadata_path = DATASETS_DIR / case_name / "metadata.json"

        # Only download if we have the metadata but not the audio
        if local_metadata_path.exists() and not local_audio_path.exists():
            to_download.append((blob["name"], local_audio_path, case_name))
        elif local_audio_path.exists():
            skipped += 1

    print(f"📊 Status:")
    print(f"   Already have audio: {skipped}")
    print(f"   Need to download: {len(to_download)}")
    print()

    if not to_download:
        print("✅ All audio files already downloaded!")
        return 0, skipped, 0

    if dry_run:
        print("🔍 Dry run - would download:")
        for blob_name, local_path, case_name in to_download[:10]:
            print(f"   {case_name}/audio.wav")
        if len(to_download) > 10:
            print(f"   ... and {len(to_download) - 10} more")
        return 0, skipped, 0

    # Download missing files
    print(f"⬇️  Downloading {len(to_download)} audio files...")

    downloaded = 0
    failed = 0

    def download_one(item):
        blob_name, local_path, case_name = item
        if download_blob(sas_key, blob_name, local_path):
            return (True, case_name)
        return (False, case_name)

    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(download_one, item): item for item in to_download}

        for future in as_completed(futures):
            success, case_name = future.result()
            if success:
                downloaded += 1
                print(f"   ✓ {case_name} ({downloaded}/{len(to_download)})")
            else:
                failed += 1
                print(f"   ✗ {case_name}")

    print()
    print(f"✅ Download complete!")
    print(f"   Downloaded: {downloaded}")
    print(f"   Skipped: {skipped}")
    print(f"   Failed: {failed}")

    return downloaded, skipped, failed


def main():
    parser = argparse.ArgumentParser(
        description="Download transcription dataset audio files from Azure"
    )
    parser.add_argument(
        "--sas-key",
        help="Azure SAS key (or set AZURE_TRANSCRIPTION_SAS_KEY env var)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be downloaded without actually downloading"
    )
    args = parser.parse_args()

    # Get SAS key
    sas_key = args.sas_key or os.environ.get("AZURE_TRANSCRIPTION_SAS_KEY")

    if not sas_key:
        print("❌ Error: No SAS key provided")
        print()
        print("Please provide the SAS key via:")
        print("  1. Environment variable: export AZURE_TRANSCRIPTION_SAS_KEY='...'")
        print("  2. Command line: --sas-key '...'")
        print()
        print("The SAS key can be found in Secrets.xcconfig (base64 encoded)")
        sys.exit(1)

    # Decode if base64 encoded
    sas_key = decode_sas_key(sas_key)

    # Ensure dataset directory exists
    if not DATASETS_DIR.exists():
        print(f"❌ Error: Dataset directory not found: {DATASETS_DIR}")
        print("Make sure you have the datasets submodule initialized.")
        sys.exit(1)

    # Sync the dataset
    downloaded, skipped, failed = sync_dataset(sas_key, dry_run=args.dry_run)

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
