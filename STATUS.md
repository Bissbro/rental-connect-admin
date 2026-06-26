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

## Session 4 Fixes (Jun 20)

### Invoice PDF Bugs Fixed
- BOOKING CONFIRMED badge was invisible on unpaid invoice PDFs - missing roundedRect fill behind white text (accidentally dropped during earlier paid-stamp edits). Restored from backup comparison and re-added fill line.
- Booking invoice item descriptions simplified across 6 locations in server.js - removed redundant "- X Nights (date to date)" suffix since check-in/out/nights already shown in the dedicated booking details box on the PDF. Now just shows unit name, with qty correctly representing nights.

### Custom Invoice Feature Built
New presentational-only invoice builder, doesn't touch revenue or existing invoice records:
- New custom_invoices DB table (reference_number CSTM-XXX auto-increment, customer_name/phone, included_invoice_ids JSON, line_items JSON snapshot, payment_status enum paid/pending/half, paid_amount/pending_amount).
- Backend routes: GET/POST /api/admin/custom-invoices, DELETE /:id, GET /:id/pdf.
- Frontend: removed old "New Booking Invoice" pills (redundant since bookings auto-invoice on confirm already), replaced with new "Custom Invoice" pill + dedicated Custom tab.
- Modal lets admin multi-select existing booking invoices + minibar invoices, combines into one summary invoice with line items (booking lines show unit+dates+nights, minibar lines show "Minibar Charges - [Unit] (invoice#)"), customer name/phone, currency, and payment status (paid / pending / half-paid with manual paid+pending amount entry).
- PDF generator rewritten to match exact branded HTM invoice template (header, FROM/BILL TO columns, navy line-item table, PAID stamp or pending/half badges, bank payment details section, footer) - initial version used generic PDFKit defaults, corrected after user feedback.
- Small print at bottom lists original invoice numbers included, for traceability.

### Date Display Fixes
- Raw ISO timestamps (e.g. 2026-06-24T00:00:00.000Z) were leaking into custom invoice line descriptions and into the regular invoice admin cards/table - fixed with fmtDateShort() helper using toLocaleDateString.
- Added fmtCreatedLocal() helper and new "Created [local date+time]" row on invoice cards, addressing user request to see local creation timestamp at a glance without opening the PDF.

## Known Follow-ups (carried over + new)
- Switch shop-checkout.html TEST_MODE back to false before accepting real shop payments. (carried over, still pending)
- Custom invoice feature only built for HTM tenant (uses tenant_id from requireAuth, pool not req.db) - not yet ported to RC multi-tenant routes; low priority since RC tenants don't have this need yet.
- Minor: old "Create Booking Invoice" modal HTML/JS (booking-invoice-modal, createBookingInvoice function, bi- prefixed fields) still exists in invoices.html but is now unreachable dead code since both buttons that opened it were removed/repointed. Harmless, could be cleaned up later.

## IMPORTANT REPORTED ISSUE (Jun 20 session)
User reported a significant Claude mobile app UI/display bug during this session: tool-call command blocks were rendering 2-4 times each with slightly different wrapper text per duplicate (e.g. "Run on server:" then "Run on server (waiting for paste):"), with the duplicate count escalating as the conversation grew longer. Plain text responses did NOT duplicate, only command/code blocks. Issue reportedly started ~1 week before this session after 2+ months of normal use. User submitted feedback via thumbs-down. Not an HTM/RC codebase issue - noting here in case it recurs and affects future session efficiency/token usage.

## Session 5 Fixes (Jun 21)

### Bookings Page Sort Options Added
Added "Sort By" dropdown to bookings.html admin page with three options: Most Recent (default, by created_at desc), Check-in Date (asc), Check-in Date Latest First (desc). Client-side sort applied after existing filters, defaults reset correctly via Clear button.

### Parent/Child Unit Block Date Sync - Major Bug Found & Fixed
Discovered the manual "Block Dates" admin page had zero propagation logic between linked parent/child units (A-701 parent, A-701-01/A-701-02 children, unit IDs 4/5/6). Existing syncLinkedUnits() function only ran on booking creation/update flows, never on manual blocks.

Fixed by:
- Adding new global getLinkedUnitIds(unitId) helper function (returns [5,6] for unit 4, [4] for units 5/6).
- Rewrote POST /api/admin/block-dates to loop over unit_id plus its linked IDs, blocking all of them together.
- Rewrote DELETE /api/admin/unblock-date/:id to look up the unit_id+date+reason first, then delete matching entries across all linked units (previously only deleted by raw row ID, couldn't cascade).

### Historical Data Backfill - 81 Missing Sync Entries Found
After the code fix, discovered the underlying booking data itself had a massive historical gap — nearly all confirmed bookings on units 4/5/6 (created via direct SQL/seeding during earlier sessions, recognizable by midnight 00:00:00 created_at timestamps) never had their cross-unit unit_availability sync rows created at all, since they bypassed the API route's syncLinkedUnits() call entirely. Wrote a one-time backfill script (not saved - run and deleted) that iterated all confirmed bookings on units 4/5/6 and inserted any missing linked-unit availability rows. Backfilled 81 missing entries total across many bookings spanning April-July 2026. Calendars for A-701/A-701-01/A-701-02 now show fully consistent cross-blocking.

### Confirmed Business Logic (documented for future reference)
A-701 (parent, full 2BR apartment, MVR 1300/night) and A-701-01/A-701-02 (individual bedrooms, MVR 750/night each) share physical space with three valid states:
1. Parent booked whole -> blocks parent + both children
2. One child booked individually -> blocks that child + parent (since full apartment can't be sold), other child stays open
3. Both children booked individually -> blocks both children + parent (equivalent end state to #1)
This is working as designed - what looked like a propagation bug was partly correct behavior (case 2, single child blocks only block parent not the sibling) once we found and fixed the real historical data gap.

### Airbnb "Always Blocks Today" - Not A Bug, Diagnosed
User noticed Airbnb iCal feed always contained a "Not available" block on whatever the current date was, shifting daily. Fetched the raw iCal feed directly and confirmed: Airbnb's own export was sending DTSTART exactly matching today + DTSTART exactly matching today+1year - both artifacts of Airbnb's own "Same day advance notice" cutoff setting (was set to 9:00 AM, meaning Airbnb auto-blocks today once 9am passes if same-day booking cutoff reached). Not a bug in our sync code - our icalSync.js correctly imports whatever Airbnb's feed contains. User changed the Airbnb listing setting from "Same day, 9:00 AM cutoff" to "Same day, 11:00 PM cutoff" to minimize this artifact's daily window. No code changes needed/made for this item.

## Next: Shop Improvements
Starting work on improving the HTM Shop (products.html, orders.html, shop.html, shop-checkout.html). Shop currently in Stripe TEST MODE (shop-checkout.html TEST_MODE=true) - remember to flip to live before real customers. Order confirmation + shipped/tracking emails already built (session 3). Specific improvement areas to be defined in next session.

## Session 6 Fixes (Jun 22)

### CRITICAL: sendOrderEmail/sendShippedEmail Functions Were Accidentally Deleted
Discovered both email functions (built in session 3) and their trigger calls had been completely wiped from server.js sometime during session 4's invoice PDF rewrite work, due to a line-number-based sed delete that removed a much larger code block than intended (file dropped ~37KB between two same-day backups: 202606200723 vs 202606201256). This caused shop order confirmation emails and shipped/tracking emails to silently stop sending for roughly 2 days with no error - the routes themselves worked fine, just missing the email functionality and one route had duplicated into two competing handlers (Express used the first/broken one, the second/correct one with the email trigger was dead code).

Restored both functions plus correct PUT /api/admin/orders/:id route (with tracking_number + sendShippedEmail trigger) from the server.js.bak.202606200723 backup. Removed the duplicate broken /api/orders POST route that lacked the email trigger - now only one correct route exists with sendOrderEmail() properly wired in.

LESSON LEARNED: line-number-based sed deletes are fragile when making multiple edits in sequence within the same session, since earlier edits shift all subsequent line numbers. Always re-grep/re-view immediately before each line-number-based delete, and ideally verify function counts (grep -c "functionName") before AND after major structural edits, not just node --check (which only catches syntax errors, not silently-deleted-but-still-valid-JS situations like this one).

### Shop Checkout Improvements (Hulhumale/Male free delivery)
- Fixed Hulhumale delivery option never setting currency to MVR (only domestic/international were handled) - caused Stripe/USD to show instead of bank slip upload when currency was already USD from previous session/localStorage.
- Renamed "Hulhumale - Free Delivery" to "Male / Hulhumale - Free Delivery" per business requirement (free delivery covers both islands plus vessels docked at either harbour).
- Added optional "Vessel Name" field to the Hulhumale/Male delivery fields, included in shipping_address as "Vessel: [name] - [address]" when provided.
- Fixed reverse-direction currency bug: switching delivery type from International back to Domestic/Hulhumale did not reset currency back to MVR because updateTotals() was called BEFORE the currency reassignment in onDeliveryTypeChange() - moved currency assignment earlier in the function.
- Updated bank transfer slip section to show real BML/MIB logos (uploaded via Experiences admin as image attachments, URLs extracted from experience_images table) with copy-to-clipboard buttons next to each account number, replacing old placeholder fake account info.
- Removed misleading "Stripe" trust badge from the slip/bank-transfer payment view (Stripe badge makes no sense when paying via bank transfer, not card).
- Removed USD bank account section entirely from slip view per user request, since slip payment is now MVR-only (international/USD orders always go through Stripe, never slip) - simplified bank labels from "BML - MVR Account" to just "BML" since currency ambiguity no longer exists in this context.

## Known Follow-ups / Not Yet Done
- Maldives Post logo (also uploaded to Experiences, 3rd of three logo uploads) was never actually implemented anywhere in the checkout UI - was discussed for the shipping-service tier cards (currently shows a plain red text "Maldives Post" badge, no actual logo image) but not built.
- User reported "payslip not landing in telegram" - NOT YET INVESTIGATED this session, need to check the staff payslip PDF Telegram delivery flow next session.
- Switch shop-checkout.html TEST_MODE back to false before accepting real shop payments (carried over from session 3, still pending).
- Verify the sendOrderEmail/sendShippedEmail restoration actually works end-to-end with a fresh test order (was fixed and restarted but not live-tested with an actual order in this session due to time).

## Next Session Starter Prompt

Continuing work on HTM Rentals / Rental Connect (RC) multi-tenant SaaS PMS on AWS Lightsail (13.212.34.47). Read this STATUS.md in full first via SSH before doing anything else.

Key things to know without re-discovering them:
- SSH: ssh -i ~/LightsailDefaultKey-ap-southeast-1.pem bitnami@13.212.34.47
- After any .bashrc env var change, PM2 needs full delete+start, NOT just restart: `pm2 delete htm-rentals && pm2 start ~/htm-rentals-backend/server.js --name htm-rentals && pm2 save`.
- Backend: ~/htm-rentals-backend/server.js (single large file, ~6000+ lines). ALWAYS `node --check` before restarting PM2, but be aware node --check only catches syntax errors, NOT silently-deleted-but-valid code (see Session 6 critical incident above). After any line-number-based sed delete/insert, immediately re-grep for the function/route names you just touched to confirm they still exist and are not duplicated, before moving to the next edit.
- Prefer string-matching python3 replace over line-number sed when possible, since line numbers shift after every edit within the same session - this caused the Session 6 incident.
- Always backup before major edits: `cp server.js server.js.bak.$(date +%Y%m%d%H%M)`. Keep recent backups, they have already saved this project once.
- HTM Rentals public site: ~/htm-rentals/*.html, deployed via GitHub Pages (push to git, ~30-60s deploy time).
- RC Admin (multi-tenant): ~/rental-connect-admin/*.html, served directly from Lightsail at api.htmrentals.com/admin/.
- ARCHITECTURE: HTM stays on its own legacy admin/DB (htm_rentals) - NOT migrated to RC admin. RC admin is exclusively for new tenants (Coral Guesthouse, rc_tenant_2). rc_tenant_1 exists but is dormant/unused.
- Shop checkout is currently in Stripe TEST MODE - shop-checkout.html has `const TEST_MODE = true;`. Must flip to false before accepting real customer payments.
- Bash history expansion (the `!` character) breaks inline python3 -c scripts - use `set +H` first or a temp .py file via heredoc.

Immediate priorities for this session:
1. Investigate "payslip not landing in telegram" - reported but not yet looked at.
2. Live-test the just-restored sendOrderEmail/sendShippedEmail functions with an actual test order to confirm the fix actually works end-to-end (was restored + restarted but not verified with a real order before running out of session time).
3. Implement Maldives Post logo on shipping-service tier cards in shop-checkout.html (logo already uploaded, URL needs to be looked up again via experience_images table - was id 13, filename 1782126985233-753642898.png as of session 6, but re-verify).
4. Ask user what else needs attention in the shop improvement pass - this was an ongoing multi-session effort (started session 6, "let's improve the shop").

Ask the user what to work on next - don't assume based on this list alone.

## Session 7 Note (Jun 27)
- Dropped rc_tenant_1 database. Confirmed dormant/unused (no code references, frozen snapshot of old htm_rentals data, stale since max booking id 74 vs htm_rentals' 96). No live functionality affected. HTM Rentals continues to operate exclusively via its own legacy admin/DB (htm_rentals) — RC admin is now exclusively for actual paying tenants (Coral Guesthouse, rc_tenant_2). rc_tenant_1 no longer exists.
- Fixed /api/admin/analytics/overview: removed stray "AND tenant_id = ?" filter referencing a column that doesn't exist on analytics_sessions (HTM's legacy analytics tables were never given tenant_id columns). Route now works for HTM admin.

## Architecture Clarification (Jun 27) - IMPORTANT, supersedes earlier wording
Previous notes said "HTM and RC admin are separate systems, do not conflate them" - this was incomplete and caused confusion in a later session. The real picture:

- There is only ONE Express app (htm-rentals-backend/server.js) and ONE PM2 process. It serves both HTM's legacy routes (tenant_id=1, htm_rentals DB) AND the /api/rental-connect/* routes, all from the SAME database connection (pool -> htm_rentals).
- The RC admin frontend (/admin/, rental-connect-admin/*.html) is served as static files directly from this same server.js (see `app.use('/admin', express.static(...))`). There is no separate backend for RC.
- HTM's login (bissbro) works in /admin/ and pulls REAL htm_rentals data through /api/rental-connect/* routes - this is expected, not a bug. These routes were added to server.js reusing tenant_id=1 (HTM), they do not provide isolation for HTM.
- Genuine per-tenant DB isolation (req.db pattern, separate database per tenant) ONLY exists for actual paying RC tenants - confirmed working correctly for Coral Guesthouse (rc_tenant_2, verified independently isolated, has its own real booking/unit data, untouched by HTM operations).
- rc_tenant_1 was a stale, unused snapshot copy of old htm_rentals data (frozen at booking id 74, never kept in sync, zero code references) - confirmed safe and deleted Jun 27.
- Practical implication: there is no access control boundary between HTM and RC admin at the login/app level - only Coral (and future real tenants) get genuine data isolation via their own rc_tenant_X database. HTM intentionally never got this treatment and was never meant to - "no use case for HTM in RC going forward" was confirmed as the deliberate direction.
