# MarkLens Privacy Policy

_Last updated: {{RELEASE_DATE}}_

MarkLens is a local, offline application. **It collects nothing.**

- No accounts, no telemetry, no analytics, no crash reporting.
- Documents you open are read from your disk and rendered on your screen.
  They are never transmitted anywhere.
- The app stores its own session and settings files locally
  (`docs/05_SESSION_AND_SETTINGS.md` describes exactly what and where);
  these contain file paths you opened and your preferences, and never
  leave your machine.

Two optional features use the network, both under your control:

1. **Update check** (Settings → Network; on by default): an HTTPS request
   to GitHub's public API (`api.github.com`) to compare version numbers.
   GitHub sees this request like any web request (your IP address). Turn it
   off and MarkLens makes no requests at all.
2. **Remote images** (off by default): if you enable it, images referenced
   by `http(s)` URLs inside documents are fetched from whichever host the
   document names. Leave it off to guarantee documents cannot trigger any
   network activity.

Questions: `{{CONTACT_EMAIL}}`.
