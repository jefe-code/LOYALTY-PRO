# LOYALTY PRO — MVP starter

This is the first build foundation, not yet the complete production SaaS.

## Files
- `index.html` — login/signup and business dashboard interface.
- `styles.css` — responsive dark premium visual design.
- `app.js` — Supabase Auth connection and create-business flow.
- `supabase-schema.sql` — database tables, Row Level Security and secure business onboarding.

## Supabase setup (free tier to start)
1. Open https://supabase.com/dashboard and create a project named `LOYALTY-PRO`.
2. Choose a strong database password and save it privately.
3. In the project, open **SQL Editor** → **New query**.
4. Open `supabase-schema.sql`, copy all its contents, paste into SQL Editor and press **Run**.
5. Open **Authentication** → **Providers** and ensure Email is enabled.
6. For first tests, open **Authentication** → **URL Configuration** and add your local/site URL to the allowed redirect URLs if needed.
7. Open **Project Settings** → **API** (or **Connect**) and copy:
   - Project URL
   - Publishable key (or legacy anon/public key)
8. In `app.js`, replace:
   - `PASTE_YOUR_SUPABASE_PROJECT_URL_HERE`
   - `PASTE_YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE`
9. Keep the publishable/anon key only. NEVER paste the database password or `service_role` / secret key into frontend code.
10. Serve the folder through a local static server or deploy it to Netlify/GitHub Pages. ES modules may not work when opening `index.html` directly as a `file://` URL.

## Test
1. Open the site.
2. Choose **Create account** and register with an email you can access.
3. Confirm your email if Supabase asks you to.
4. Log in.
5. Press **Add business**, enter a business name and a simple slug such as `cafe-lumiere`.
6. The business should appear in the dashboard.

## Important current limitations
- This is the initial owner onboarding and dashboard shell.
- Customer self-enrolment, public digital card retrieval, stamp validation, voucher generation/redemption, push notifications, Google Wallet and super-admin controls are not finished in this starter.
- The SQL deliberately does not expose customer contact information publicly.
- Do not launch commercially until the remaining secure backend workflows and privacy/consent requirements are implemented and tested.

## Free vs paid
You can build and test this starter on free tiers. Costs may arise later for a custom domain, SMS/WhatsApp messages, higher database/storage/traffic limits, email delivery, or paid wallet/notification services. Check current provider limits before a commercial launch.
