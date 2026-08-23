# Security Policy

## Supported versions

The latest release only.

## Reporting

Please report vulnerabilities privately via GitHub's private vulnerability
reporting on this repository, or email `{{CONTACT_EMAIL}}`. You should
receive a response within 7 days; coordinated disclosure within 90 days.

## Scope

MarkLens treats every opened document as untrusted input. Explicitly in
scope as security issues (see `docs/10_SECURITY_PRIVACY.md`):

- Any code execution triggered by document content (MDX, HTML, links)
- Any write, rename, or delete of user files by the app
- Any network request outside the two documented opt-in features
- Crashes or hangs caused by crafted files

Please do not open public issues for the above before contact.
