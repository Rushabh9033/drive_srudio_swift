# Drive Studio — legal pages (App Store)

Static pages for App Store Connect **Privacy Policy** and **Support** URLs (Guideline 5.1.1).

| File | Purpose | Host as |
|------|---------|---------|
| `privacy.html` | Privacy Policy | `https://drivestudio.app/privacy` |
| `support.html` | Support | `https://drivestudio.app/support` |
| `terms.html` | Short Terms / image rights | `https://drivestudio.app/terms` (optional) |

## Before App Store Connect

1. Host these files on **HTTPS** (GitHub Pages from this folder, Cloudflare Pages, Netlify, or your domain).
2. Point Connect fields to the live URLs (see `STORE_LISTING.md`).
3. Replace `privacy@drivestudio.app` / `support@drivestudio.app` with real inboxes.
4. In-app copy mirrors this policy via Settings → Privacy Policy (`/privacy` route). Keep HTML and `lib/core/legal/legal_copy.dart` aligned when you change data practices.

## GitHub Pages (example)

From repo root, publish `docs/legal/` (or copy into `docs/` site root) so paths resolve as `/privacy.html` or map clean URLs with a Pages `_redirects` / CNAME to `drivestudio.app`.
