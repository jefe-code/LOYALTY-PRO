# LOYALTY PRO — fresh GitHub Pages starter

This is a new visual and technical foundation for LOYALTY PRO. It is intentionally different from the NEXORA visual identity.

## Files
- `index.html` — public product website and business login
- `style.css` — responsive visual system
- `app.js` — language switcher, Supabase client and login
- `dashboard.html` / `dashboard.js` — business dashboard
- `card.html` / `portal.js` — customer card creation and lookup
- `portal.css` — customer and dashboard styling
- `supabase-migration.sql` — secure RPC functions for the existing starter schema

## Supabase setup
The project URL and publishable key are configured in the JS files. A publishable key is designed for browser use; never put a `service_role` or secret key in frontend code.

1. Open Supabase → SQL Editor.
2. Keep the original `loyalty_pro_supabase_starter.sql` schema already executed.
3. Run `supabase-migration.sql`.
4. In Supabase Authentication, create a business owner user (or use the sign-up flow you already configured).
5. Sign in from the website and create a business workspace from the dashboard.

Project URL used: `https://skizdeuozmuzmehyvvtk.supabase.co`

## GitHub Pages
Upload the contents of this folder to the repository root (not the ZIP itself):
`index.html`, `style.css`, `app.js`, `dashboard.html`, `dashboard.js`, `card.html`, `portal.js`, `portal.css`, `supabase-migration.sql`, `README.md`.

Then go to **Settings → Pages → Deploy from a branch → main → /(root)**.

## Current scope / honest status
- Public marketing site: built.
- English / French / Arabic interface and RTL: built for the public site.
- Supabase email/password login: wired.
- Business workspace creation: wired to the migration RPC.
- Customer card creation and lookup: wired to narrow RPC functions.
- Dashboard metrics: reads the existing tenant-scoped tables after login.
- Stamp/reward issuance: the secure stamp and voucher redemption RPCs are included, but the dashboard staff controls and automated voucher issuance still need the next development pass.
- Google Wallet, iOS/Android push, OTP recovery, staff invitations, billing and production anti-abuse controls are later phases.

## Important security notes
The public card token acts like a private access link. Do not post it publicly. Public card functions return only the limited fields needed to display a card, not customer email or phone. Stamp creation requires an authenticated business member. Never expose Supabase secret/service-role credentials in browser files.

## v3 Card Design Studio
- `card-design-migration.sql` adds tenant-scoped design settings and a public-safe theme lookup. Run it once in Supabase SQL Editor.
- Business owners can choose six card styles, primary/accent colours, monogram, stamp symbol and corner shape in the dashboard.
- The public card loads the saved brand design by business slug.
- Replace the repository files with this folder; do not upload the ZIP itself as the website root.
