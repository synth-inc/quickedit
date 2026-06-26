# Server changes: QuickEdit magic-link login

This is an implementation ticket for the **Onit backend** (the server behind
`https://onit-server-v2-*.herokuapp.com`, endpoint `POST /v1/auth/login/link`).
It describes the changes needed so that **magic-link email login works for the
standalone QuickEdit macOS app** without breaking the existing Onit/Dictate app.

The macOS **client changes are already done** (see "Client contract" below) and
the **website redirect** is being handled separately by the web team. Your scope
is the **API endpoint, the magic-link URL it generates, and the email template.**

---

## Background

QuickEdit was split out of the Onit/Dictate app into its own macOS app with:

- bundle id `inc.synth.onit.quickedit` (release), `inc.synth.onit.quickedit.dev` (debug)
- a **different** custom URL scheme: **`onit-quickedit`** (the old app used `onit`)

The same backend and the same `POST /v1/auth/login/link` endpoint serve **both**
apps. Today the endpoint receives only `{ email }`, so it can't tell which app is
asking. As a result QuickEdit's magic link:

1. redirects to the **wrong scheme** (`onit://`), which opens the old Onit/Dictate
   app (or the website) instead of QuickEdit, and
2. the email is branded **"Welcome to Onit"** instead of QuickEdit.

## The end-to-end flow (target state)

```
QuickEdit app
   │  POST /v1/auth/login/link  { "email": "...", "app": "quickedit" }
   ▼
Backend  ── generates one-time login token
         ── builds magic-link URL to the WEBSITE, carrying the token AND the app
         ── sends email using the QuickEdit template
   │
   ▼  (user clicks link in email)
Website  ── reads token + app, 302-redirects to the app's custom scheme:
            app=quickedit  →  onit-quickedit://?token=<token>
            app=onit       →  onit://?token=<token>        (existing behavior)
   │
   ▼
QuickEdit app  ── receives onit-quickedit://?token=<token>
               ── exchanges it via the existing token-login endpoint → session
```

---

## Client contract (already shipped in the macOS app — do not change)

`POST /v1/auth/login/link` request body now includes an `app` discriminator:

```json
{
  "email": "user@example.com",
  "app": "quickedit"
}
```

- `app` is a string. The QuickEdit app always sends `"quickedit"`.
- The existing Onit/Dictate app sends **no `app` field** (or `"onit"` if/when updated).
- **Backwards compatibility is required:** if `app` is missing/empty/unknown,
  behave exactly as today (Onit/Dictate branding + `onit://` scheme).

---

## Required backend changes

### 1. Accept and validate the `app` field
- Parse `app` from the `/v1/auth/login/link` request body.
- Map it to a per-app config. Suggested mapping (extend as needed):

  | `app` value      | deeplink scheme    | email template / brand |
  |------------------|--------------------|------------------------|
  | `"quickedit"`    | `onit-quickedit`   | QuickEdit              |
  | `"onit"` / absent| `onit`             | Onit (existing)        |

  Prefer a small lookup table/config over hard-coded `if`s, so adding future
  apps is a one-line change. Unknown values → fall back to the Onit default.

### 2. Carry the app through to the magic-link URL
The email links to the website (e.g. `https://<web-host>/auth/login?...`). Include
enough information for the website to pick the right redirect scheme. Add the app
(and/or the resolved scheme) as a query param on that URL, e.g.:

```
https://<web-host>/auth/login?token=<token>&app=quickedit
```

(The website team will read `app` and redirect to `onit-quickedit://?token=<token>`.
Coordinate the exact param name with them — `app` is the proposed name.)

> Note: the **token format and the token-exchange endpoint stay the same** — only
> the *scheme the website redirects to* changes, driven by `app`.

### 3. Use the QuickEdit email template
- Select the email template by `app`.
- For `app == "quickedit"`: QuickEdit branding — subject, preheader, body copy,
  logo, and any "Welcome to …" text should say **QuickEdit**, not Onit.
- Keep the Onit template unchanged for the default path.

### 4. (Verify, likely no change) token exchange
The app exchanges the token via the existing login-token endpoint
(`FetchingClient.loginToken`, the `/v1/auth/login/...` token route). Confirm it
is **not** app-scoped in a way that would reject a QuickEdit-issued token. If it
is, allow QuickEdit tokens through.

---

## Acceptance criteria

- `POST /v1/auth/login/link` with `{ "email", "app": "quickedit" }` sends an email
  whose link, once the website redirects, opens **`onit-quickedit://?token=…`**.
- That email uses **QuickEdit branding** ("Welcome to QuickEdit", QuickEdit logo).
- The same endpoint with **no `app`** (or `"onit"`) behaves exactly as before
  (Onit branding + `onit://`). No regression for the existing app.
- The token returned exchanges successfully and logs the QuickEdit user in.

## Out of scope (handled elsewhere)
- **macOS app**: already updated — sends `app: "quickedit"` and accepts the
  `onit-quickedit://` callback.
- **Website redirect** (`onit-quickedit://` vs `onit://`): handled by the web team;
  just make sure the magic-link URL carries `app` (step 2) so they can branch on it.
