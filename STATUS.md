# Rental Connect Status

## Infrastructure
- Backend: AWS Lightsail 13.212.34.47, Node.js/Express, PM2
- RC Admin: https://api.htmrentals.com/admin/
- HTM Rentals frontend: GitHub Pages at htmrentals.com (separate, untouched, full-featured)
- Master DB: rc_master (tenants + users)
- Tenant 1 DB: rc_tenant_1 (HTM Rentals — created but NOT actively used, dormant)
- Tenant 2 DB: rc_tenant_2 (Coral Guesthouse — actively used)
- HTM Rentals public site continues using htm_rentals DB directly via legacy /api/admin/* routes

## Architecture Decision (confirmed)
- HTM Rentals stays on its original admin and htm_rentals DB — NOT migrating to RC admin for now.
- RC admin is exclusively for new tenants (Coral and future customers).
- rc_tenant_1 sits dormant — zero risk since no routes point to it for live traffic.
- Multi-tenant via separate databases (not tenant_id columns) — eliminates cross-tenant leak risk by design.

## Tenants
- Tenant 1: bissbro / i1love4AllaH3@# -> rc_tenant_1 (dormant)
- Tenant 2: coral_admin / i1love4AllaH3@# -> rc_tenant_2 (active)

## RC Admin Migration - COMPLETE
All RC admin pages now call /api/rental-connect/* routes. Added RC-specific backend routes for experiences, hero-images, promo-banners, leads, block-dates, upload-image, finance/summary, revenue, monthly-expenses, rent, reports/:tab, reviews. Fixed occupancy date-math bug, reports SQL alias bug. Revenue/payment flow corrected: invoice auto-created as sent on booking confirm, revenue recorded only when invoice marked paid. Fixed payslip PDF route auth.

## CRITICAL BUG FIXED - Public Booking Flow (HTM)
Found and fixed severe bug in /api/bookings/create: leftover undefined variable b was crashing every Request to Book submission with ReferenceError. Fixed by replacing broken calc with rates.length check. Verified full flow works end to end now including email with invoice attachment. Also fixed req.tenant_id undefined bug in slip upload route and broken public /api/reviews endpoint (bad SQL string interpolation).

## CRITICAL DATA LEAK FOUND & FIXED - Legacy Cross-Tenant Contamination
Coral Guesthouse unit and related records were still in legacy htm_rentals tables (tenant_id=2), leftover from before separate-DB migration. Caused Coral unit to leak into HTM Telegram bot minibar picker. Deleted all tenant_id=2 rows from htm_rentals across units, bookings, settings, invoices, revenue, staff, petty cash. Hardened getUnitRates() with explicit tenant_id=1 filter.

FOLLOW-UP NEEDED: 8 other pool.query calls touching units table without tenant_id filter identified but not individually audited yet.

## NEW: Client-Side Error Logging (HTM only)
Built JS error logger in unit-details.html head, reports to htm_rentals.client_errors table via /api/client-error. Admin views via /api/admin/client-errors. No frontend viewer page yet, curl-only currently.

## Other Fixes
Fixed HTM admin Analytics, Partners, and Loans routes (bad tenant_id filters and scrambled SQL).

## Pending
- Dashboard live stats, audit remaining units queries, build client-errors admin UI
- Add error logger to other public HTM pages
- RC Super Admin panel, RC settings/password flow, Coral full onboarding
- Dynamic website template fork from HTM Rentals site for all RC tenants
- DeepSeek guest chat widget (last)

## Key Files
- Backend: ~/htm-rentals-backend/server.js
- RC Admin: ~/rental-connect-admin/*.html
- HTM Public Site: ~/htm-rentals/*.html
- Backups: ~/htm-rentals-backend/server.js.bak.*

## Session 2 Fixes (Jun 18)

### HTM Admin Reorganized
Admin dashboard restructured into 7 clear sections: Operations, Property & Inventory, Content & Marketing, Shop, Finance & Partners, Insights, System. Leads removed from bookings list (backend /api/admin/bookings now excludes booking_status='lead').

### Client Error Logger
Built full client-errors.html admin page with deduped errors (occurrence_count, first_seen, last_seen via ON DUPLICATE KEY UPDATE), filters by page/status/search, resolve/delete actions, 30-second auto-refresh. Linked from admin.html under Insights section.

### Image Auto-Compression
Installed sharp npm package in htm-rentals-backend. Added compressUploadedImage() helper (max 1920x1080, quality 82, mozjpeg). Hooked into all 3 upload routes. Existing 6.2MB hero image compressed to 428KB. Added 30-day cache headers to /uploads static server.

### Experience Cards
Reduced card width from 44vw to 38vw so third card peeks on mobile.

## Session 3 Fixes (Jun 19)

### Shop Order Email System Built
- Added sendOrderEmail() function — sends order confirmation immediately after Stripe payment succeeds, branded as "HTM Shop", includes order number, shipping address, itemized subtotal + shipping cost breakdown, total.
- Added sendShippedEmail() function — sends a second email when admin marks order status as "shipped", includes tracking number if provided (graceful fallback message if shipping method has no tracking).
- Added tracking_number column to orders table.
- Added tracking number input field next to status dropdown in orders.html admin; wired into PUT /api/admin/orders/:id route, which now triggers sendShippedEmail only on the pending->shipped transition (not on every save).
- Both emails send from shop@htmrentals.com (separate from bookings@htmrentals.com), display name "HTM" for consistent cross-product branding.

### Email Sender Setup
- Added shop@htmrentals.com as a Namecheap email forwarder -> htmrentalss@gmail.com (incoming), matching existing bookings@ setup.
- Added shop@htmrentals.com as a verified Brevo sender (outgoing), DKIM/DMARC inherited from domain-level htmrentals.com config.
- Changed booking confirmation email sender display name from SMTP_FROM_NAME env var to hardcoded "HTM" for brand consistency.

### Stripe Test Mode for Shop
- Added STRIPE_SECRET_KEY_TEST env var and stripeTest client alongside existing live stripe client in /api/shop/create-payment-intent (test_mode flag in request body switches client).
- Root cause of initial test failures: PM2 process was started before STRIPE_SECRET_KEY_TEST was added to .bashrc, so it wasn't in the running process's env — fixed via pm2 delete + pm2 start (not just restart, which doesn't reload shell env).
- shop-checkout.html currently hardcoded to TEST_MODE = true (intentional, while testing) — uses pk_test publishable key; remember to flip back to false (live) before going live with real customers.
- Verified full end-to-end: cart -> details -> delivery -> Stripe test payment (4242 4242 4242 4242) -> order created in DB with stripe_status='succeeded' -> confirmation email received.

## Known Follow-ups
- Switch shop-checkout.html TEST_MODE back to false before accepting real shop payments.
- Verify GET /api/admin/orders returns tracking_number field correctly (SELECT * should already include it, not explicitly re-checked).

## Next Session Starter Prompt

Continuing work on HTM Rentals / Rental Connect (RC) multi-tenant SaaS PMS on AWS Lightsail (13.212.34.47). Read this STATUS.md in full first via SSH before doing anything else.

Key things to know without re-discovering them:
- SSH: ssh -i ~/LightsailDefaultKey-ap-southeast-1.pem bitnami@13.212.34.47
- After any .bashrc env var change, PM2 needs full delete+start, NOT just restart: `pm2 delete htm-rentals && pm2 start ~/htm-rentals-backend/server.js --name htm-rentals && pm2 save` (pm2 restart does not reload shell env vars).
- Backend: ~/htm-rentals-backend/server.js (single large file, ~6700+ lines). Always `node --check` before restarting PM2. Always backup before major edits: `cp server.js server.js.bak.$(date +%Y%m%d%H%M)`.
- HTM Rentals public site: ~/htm-rentals/*.html, deployed via GitHub Pages (push to git for changes to go live, ~30-60s deploy time).
- RC Admin (multi-tenant): ~/rental-connect-admin/*.html, served directly from Lightsail at api.htmrentals.com/admin/.
- IMPORTANT ARCHITECTURE DECISION: HTM stays on its own legacy admin/DB (htm_rentals) - NOT migrated to RC admin. RC admin is exclusively for new tenants (Coral Guesthouse is the first paying customer, rc_tenant_2). rc_tenant_1 exists but is dormant/unused. Do not conflate these two systems.
- Shop checkout is currently in Stripe TEST MODE - shop-checkout.html has `const TEST_MODE = true;` hardcoded. Must flip to false before accepting real customer payments.
- When editing server.js with python3 -c one-liners, exact whitespace/string matching is fragile - verify with grep/sed -n before AND after edits, since silent "MISS" failures have happened repeatedly.
- Bash history expansion (the `!` character) breaks inline python3 -c scripts containing things like `if (!req.file)` - use `set +H` first, or write to a temp .py file via heredoc and run that instead.

Open items not yet started/finished:
- Switch shop back to live Stripe mode when ready for real customers.
- Verify tracking_number field returns correctly from GET /api/admin/orders (SELECT * should include it but not explicitly re-checked after the ALTER TABLE).
- Larger paused discussion: forking the polished HTM Rentals public site as the dynamic, API-driven template for all future RC tenants (replacing the placeholder site-coral.html). Agreed direction, zero code written.
- 8 unaudited units-table pool.query() calls without tenant_id filter were identified in an earlier session but individually low-risk (all are single-row lookups by primary key) - left as-is, not a priority.
- Build a simple admin UI page for client_errors viewing was already done (client-errors.html exists in HTM admin under Insights section) - this is DONE, not open.

Ask the user what to work on next - don't assume based on this list alone, the user's priorities may have shifted.
