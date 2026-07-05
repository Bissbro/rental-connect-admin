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

## Session 7 (Jun 27) - Major: Restored real multi-tenant DB isolation for RC
Root cause investigation revealed the entire per-tenant database routing system (getTenantPool, req.db, masterPool/rc_master) was fully built June 16-20 but got silently destroyed by the same bad sed delete documented in Session 6 (only the email functions were noticed missing and restored at the time - this was collateral damage that went unnoticed for a week). In its absence, RC's /api/rental-connect/* routes had been "fixed" to use the shared htm_rentals pool with tenant_id columns instead - meaning RC tenants had ZERO real isolation from HTM and from each other the whole time, just security-by-obscurity (no UI ever showed mixed data because no second real RC tenant had been tested end-to-end until tonight).

Restored:
- masterPool (rc_master) + getTenantPool()/tenantPools cache, reinserted after the main pool definition.
- requireAuth now sets req.db = getTenantPool(req.user.db) when the JWT carries a db field.
- All 21 /api/rental-connect/* routes converted from pool.query (htm_rentals, tenant_id filtered) to req.db.query (tenant's own isolated database, no tenant_id needed since the column doesn't exist in rc_tenant_X schemas).
- generateTenantInvoicePDF and the payslip PDF route updated to accept/resolve a db connection instead of always using pool.
- Split login into two separate endpoints: /api/admin/login (HTM only, admin_users table, no rc_master lookup) and new /api/rental-connect/login (RC tenants only, rc_master.tenant_users). Previously both frontends called the same /api/admin/login, which checked rc_master first - meaning any RC tenant's credentials would also work on HTM's legacy login form and vice versa.
- Updated rental-connect-admin/index.html to call the new /api/rental-connect/login endpoint.
- Deleted duplicate user records that existed in the wrong system: removed bissbro from rc_master.tenant_users (was pointing at the now-deleted rc_tenant_1), removed coral_admin from htm_rentals.admin_users (was a stray duplicate letting Coral's credentials work on HTM's own legacy login, pulling real HTM data through the unscoped pool).
- Dropped rc_tenant_1 database - confirmed dead/unused snapshot of old htm_rentals data, frozen since booking id 74, zero code references anywhere.

Verified end-to-end: bissbro -> HTM legacy admin only, sees only htm_rentals data. coral_admin -> RC admin only, sees only rc_tenant_2 data (1 unit, 1 test booking - correctly isolated, not 85 HTM bookings). Cross-login in either direction now correctly fails with "Invalid credentials."

## Corrected Architecture (supersedes all earlier session notes on this topic)
- ONE Express app (server.js), ONE PM2 process, serves both HTM legacy routes AND /api/rental-connect/* routes.
- HTM: admin_users table (htm_rentals db) + pool (direct htm_rentals connection). No tenant isolation needed or used - HTM is not multi-tenant, it's the original single-tenant app.
- RC tenants: rc_master.tenant_users table (login only) + getTenantPool(db_name) -> each tenant's own physical database (rc_tenant_2 for Coral, future tenants get their own rc_tenant_N). Real isolation - a query literally cannot reach another tenant's data regardless of any forgotten WHERE clause, because it's a different MySQL database connection entirely.
- Login endpoints are now separate and non-overlapping: /api/admin/login (HTM) vs /api/rental-connect/login (RC). Never let these merge again - that was the root cause of the cross-login bug found and fixed tonight.
- When provisioning a future RC tenant: create their rc_tenant_N database (same schema as rc_tenant_2), add a row to rc_master.tenant_users with that db_name, do NOT add anything to htm_rentals.admin_users.

## RC Product Vision & Tier Planning (Jun 27, late session)
Defined customer segments for Rental Connect, to be implemented as feature-gated tiers (not separate codebases - same per-tenant DB architecture, UI/features shown or hidden based on a tier flag):

**Tier 1 - Homestay Tourism**: individual renting 1-3 rooms/an apartment/a house. No dedicated branded website - instead gets a simple unit detail page (no Hero Slides/Promo Banners/Promotions) and a free listing slot in a "Partnered Properties" section on htmrentals.com itself. Needs: Bookings, Calendar, Block Dates, basic Invoices, Settings (minimal). Does NOT need: Leads, Minibar, Payroll, Petty Cash, Hero Slides, Promo Banners, Promotions.

**Tier 2 - Rental Business Owners**: landlords with multiple units, portfolio mindset, no real on-site staff. Adds: Leads, Petty Cash (contractor/cleaner payments), Finance/Reports, likely their own full branded website (Hero Slides/Promotions become relevant now). Still likely no Payroll (no formal staff).

**Tier 3 - Guesthouse Owners**: full operation with staff (the HTM model). Everything unlocked - Minibar, Payroll, full Finance/Reports, Reviews, Experiences, Promotions, Hero Slides, Promo Banners. This is the tier RC's current full feature set was already built for (modeled on HTM/Coral).

**Tier 4 (separate, new) - Experience/Activity Provider**: NOT a unit-renting business - offers bookable activities/services (e.g. dive trips, excursions) with no rooms. Needs its OWN dedicated schema additions (NOT reuse of units/bookings tables - explicitly decided against reuse-and-hide due to semantic mismatch: no check-in/check-out nights, no bedrooms/bathrooms, etc.). New tables needed: `activities` (name, description, photos, price, duration, max_participants, is_active) and `activity_bookings` (guest_name, guest_phone, activity_id, slot_date, slot_time, number_of_guests, status, amount). Same per-tenant isolation pattern (lives inside that tenant's own rc_tenant_X database). Low priority - build only once a real activity-provider customer is ready to onboard, not speculatively.

**Explicitly out of scope for now**: Resort/hotel-scale tier (too large an undertaking for this phase). Travel agency / cross-tenant marketplace platform (an "Airbnb-style" aggregator across ALL RC tenants, with agencies building packages) - genuinely interesting future direction but deferred as its own future "Phase 2" project, since it requires real cross-tenant data sharing, a much bigger architectural undertaking than the single-tenant-safe patterns used elsewhere.

### HTM Website Integration Plan (Partner Properties + Experiences)
Decided on the SAFE architecture after explicitly discussing and rejecting a riskier alternative:
- REJECTED approach: one new "aggregator" function that loops/queries across multiple tenant databases in a single shared code path. Risk: a bug in that one function could leak data across many tenants at once; also harder to keep narrow-field-safe consistently.
- CHOSEN approach: each opted-in tenant has their own simple, narrow, public-facing listing/availability function (hardcoded safe field list - unit_name, photos, price, amenities, availability ONLY, never guest PII or financial fields), accessed via that tenant's own getTenantPool/req.db connection - the same safe single-tenant pattern already proven in tonight's tenant-isolation fix. The orchestration layer (e.g. "check all opted-in partners after HTM has no availability") just calls each tenant's own safe function in sequence/parallel and aggregates the RESULTS only - it never directly queries multiple tenant databases itself.
- Flow: guest searches dates on HTM's own site -> HTM's own availability checked first (existing code, htm_rentals) -> if empty, automatically (no separate search bar) loop through opted-in Tier 1 tenants (flagged via e.g. show_on_htm_listings in rc_master) calling each one's narrow availability function -> show any available partner units as fallback results, each linking out to that tenant's own unit detail page where the actual booking happens (written directly into that tenant's own database).
- Same pattern applies to an "Experiences" showcase section (currently a placeholder on HTM's site, no real backing data yet) - opted-in tenants' activities shown via the same narrow-function-per-tenant pattern, via a separate flag (e.g. show_on_htm_experiences).
- Known scaling limit: live per-tenant-loop is fine at current/near-term scale (a handful to ~10-15 tenants). If tenant count grows much larger (e.g. 50+ separate Tier 1 tenants), live looping on every fallback search could strain the small Lightsail instance (real RAM constraints already identified earlier tonight) and slow down search latency. Future fix when needed: a periodically-refreshed small cache/index table (built FROM the same safe per-tenant calls, just run on a schedule instead of live per search) rather than querying tenant DBs live on every guest search. Build the per-tenant public function in a way that's cache-friendly from day one (i.e. "return this tenant's full public listing data" rather than "respond to this specific search query") so swapping in caching later is a small change, not a rewrite.
- Also flagged as future hardening (not blocking for v1): rate-limiting on the new public search endpoint (it's unauthenticated and fans out to multiple DBs, so is a potential scraping/abuse target); and ensuring the narrow public-listing function is a single shared, parameterized, well-tested function (not copy-pasted per tenant) to avoid future field-exposure mistakes via drift.

### Build Sequencing Decided
1. RC Master Admin (tenant onboarding automation) - FIRST PRIORITY, since onboarding currently requires manual SSH/SQL work for every new tenant, blocking everything else.
2. Tier-gating logic (show/hide RC admin sections based on a tenant's tier) - needed before onboarding a second REAL paying tenant, so they don't all get the full Guesthouse feature set regardless of what they're paying for.
3. Experience Provider tier (new tables) - only once a real activity-provider customer is ready, not speculative.
4. HTM website integration (Partner Properties + Experiences sections) - only once there are real Tier 1/Experience tenants with real listings worth showing; no point building a showcase for empty inventory.
5. Pricing finalization - can happen in parallel, doesn't block engineering work. Rough discussed range: Tier 1 - low/no direct monthly fee (listing-only value exchange) or low promotional rate; full branded-website tiers (2/3) discussed in the $40-80/month per property or $80-150/month flat (small portfolio) range, given RC bundles website + booking engine + invoicing + finance + payroll (replacing what would otherwise be 3-4 separate paid tools for a small operator).

## Phase 1 Prep (Jun 27, continued)
- Cleaned up rc_master.tenants: deleted stale "HTM Rentals" row (id=1, was pointing at deleted rc_tenant_1 - leftover from abandoned early system, HTM never uses this table at all since it's RC-only).
- Updated tenants.plan enum from generic ('starter','pro') to actual tier names: ('homestay','rental_business','guesthouse','experience_provider'). Coral Guesthouse set to 'guesthouse' (correct tier for its feature set).
- NEXT: tenant_users table has no tier field yet - tier lives on `tenants` table via the `plan` column (correct - tier belongs to the tenant/business, not the individual login). Login route needs to look up and return the tenant's plan so RC admin frontend can gate UI sections accordingly. This wiring not yet done - login response currently only returns tenant_id/db, not plan.
- RC Master Admin build (auth: hardcoded single super-admin user via env vars, NOT in admin_users or tenant_users; route /api/rc-master/login; separate requireSuperAdmin middleware) - decided on approach, not yet built. Next session: build login route + middleware, then onboarding form/route (create DB, clone schema from rc_tenant_2, bcrypt hash, insert into both tenants and tenant_users tables with chosen plan).

## Phase 1 COMPLETE (Jun 27/28) - RC Master Admin onboarding automation working end-to-end
Built and verified the RC Master Admin onboarding system:
- New route /api/rc-master/login: hardcoded super-admin credentials (username bissbro) via env vars, separate from admin_users/tenant_users entirely. Issues JWT with role:'superadmin'.
- New requireSuperAdmin middleware checks for that role claim - fully separate from requireAuth/HTM/RC tenant auth, no overlap risk.
- New route /api/rc-master/tenants (GET - list all tenants, POST - onboard a new tenant). POST takes {name, slug, plan, username, password}, automates: CREATE DATABASE rc_tenant_N, clone schema from rc_tenant_2 (reference tenant), bcrypt hash password, insert into both rc_master.tenants and rc_master.tenant_users.

CRITICAL FIX during this build: htm_user (the app's MySQL user) only had explicit GRANT ALL on 4 hardcoded databases (rc_master, htm_rentals, rc_tenant_1, rc_tenant_2) - no privilege to use newly-created databases. Onboarding could CREATE DATABASE rc_tenant_3 but then got "Access denied... to database 'rc_tenant_3'" on every subsequent query. Fixed permanently with a wildcard grant: `GRANT ALL PRIVILEGES ON \`rc_tenant_%\`.* TO 'htm_user'@'localhost';` (via root - root has NO password, uses unix socket auth, access via plain `sudo mysql` with no -u/-p flags, NOT via debian.cnf which is obsolete on this MariaDB version). This wildcard grant means ALL future rc_tenant_N databases will automatically work without needing this fix repeated.

Verified full flow end-to-end with a test tenant (created, confirmed schema cloned correctly - 20 tables matching Coral's, confirmed login via /api/rental-connect/login returns correct token with db:rc_tenant_3, then cleaned up/deleted the test tenant after verification).

tenants.plan enum already set to real tier names from earlier prep (homestay, rental_business, guesthouse, experience_provider) - onboarding form/API accepts plan directly.

NEXT (not yet built): 
- RC Master Admin frontend UI (currently only tested via curl/API directly - no actual HTML page yet for onboarding form or tenant list).
- Tier-gating logic in RC tenant admin UI (hide/show sidebar sections based on the tenant's plan - currently plan is stored but nothing reads it to actually gate any features yet).

## Phase 1 FULLY COMPLETE (Jun 27/28) - Frontend built and live-tested
Built rc-master.html - a self-contained single-page UI (login + onboarding form + tenant list table), served at https://api.htmrentals.com/admin/rc-master.html via the existing static file route. Not linked anywhere public - access by direct URL only, login gated by the super-admin credentials.

Live-tested successfully with a real onboarding: created tenant "Sun Siyam" (slug, plan: homestay, username: iruveli) - confirmed working end-to-end through the actual UI, not just curl. Tenant list correctly displays both Sun Siyam (rc_tenant_3, homestay, trial) and Coral Guesthouse (rc_tenant_2, guesthouse, active).

Phase 1 (RC Master Admin onboarding automation) is now COMPLETE - both backend (routes, DB permissions fix) and frontend (UI) working live. Onboarding a new RC tenant is now: open rc-master.html, fill in 5 fields, click Create Tenant. No more manual SSH/SQL required.

NEXT PRIORITY: Phase 2 - tier-gating logic in the actual RC tenant admin UI (rental-connect-admin's other pages - dashboard, sidebar, etc.) so a 'homestay' tenant like Sun Siyam doesn't see Payroll/Petty Cash/Minibar/Promotions sections meant for 'guesthouse' tier tenants. Currently tenants.plan is stored and returned correctly in login response (confirmed: /api/rental-connect/login returns tenant_id/db, but NOT yet plan - need to verify/add plan to that login response so the tenant-facing frontend can actually read and act on it).

## Phase 2 COMPLETE (Jun 28) - Tier-gating in RC tenant admin UI
- /api/rental-connect/login now joins tenants table and returns plan + tenant_name in addition to existing fields. JWT also now carries plan claim.
- index.html (RC tenant login) now stores rc_plan and rc_tenant_name in localStorage alongside existing rc_token/rc_username/rc_tenant_id.
- New shared file: rental-connect-admin/tier-gate.js - reads rc_plan from localStorage, hides nav-item links not relevant to that tier, and generically hides any nav-section header left with zero visible items underneath (no hardcoded per-section logic needed - works automatically for any future hide-list changes).
- Tier hide-lists (defined in tier-gate.js):
  - homestay: hides minibar, staff-payroll (guesthouse-only) AND leads, petty-cash, promotion, hero-slides, promo-banners, reviews, experiences (business-and-up)
  - rental_business: hides only minibar, staff-payroll (guesthouse-only)
  - guesthouse / experience_provider: nothing hidden (full feature set) - experience_provider not yet differentiated with its own UI, deferred until a real activity-provider tenant is ready (per earlier planning notes)
  - Finance/Reports/Invoices/Settings/Bookings/Block Dates/Calendar/Units/View Site intentionally NOT gated - considered useful at every tier including homestay (a single-room owner still wants revenue visibility)
- Script included via a single <script src="tier-gate.js"> line added to all 18 RC admin HTML pages (block-dates, bookings, calendar, dashboard, experiences, finance, hero-slides, invoice, leads, minibar, petty-cash, promo-banners, promotion, reports, reviews, settings, staff-payroll, units).
- Live-tested with a temporary homestay-tier test tenant created via rc-master.html: confirmed correct sections hidden (Leads, Minibar, Promotions, Petty Cash, Payroll, Hero Slides, Promo Banners, Reviews, Experiences all hidden + Experiences section header correctly disappears when empty), confirmed Dashboard/Bookings/Block Dates/Calendar/Units/View Site/Invoices/Finance/Reports/Settings all remain visible. Test tenant deleted after verification.

Phase 1 AND Phase 2 are now both complete and verified working end-to-end.

NEXT: no further phases currently scoped as urgent. Future work (lower priority, build only when actually needed): Experience Provider tier dedicated UI/tables; HTM website "Partnered Properties" + "Experiences" showcase sections (needs real opted-in tenants first); RC Master Admin nice-to-haves (edit/deactivate tenant, reset password) - not built, current flow only supports create + list.

## Phase 2.5 COMPLETE (Jun 28) - Dynamic per-tenant feature system + full Master Admin CRUD
Replaced the fixed plan-based gating (homestay/rental_business/guesthouse hardcoded hide-lists) with a fully dynamic, database-driven feature system, since RC admin itself is still being actively built and a hardcoded approach would require editing gating logic + UI every time a new feature/page is added.

### Schema (rc_master)
- New table `features`: id, key_name, label, page_url, category, sort_order, is_core. Seeded with all 19 current RC admin sections (dashboard, bookings, leads, block_dates, calendar, units, minibar, hero_slides, promo_banners, promotion, reviews, view_site, experiences, invoice, finance, reports, petty_cash, staff_payroll, settings). is_core=1 for dashboard/settings - these are always enabled for every tenant regardless of selection, never shown as toggleable.
- New table `tenant_features`: tenant_id + feature_id join table (many-to-many), FK cascade delete on both sides.
- tenants.plan enum retained as a label/preset hint only - actual gating now driven entirely by tenant_features, not by plan.

### Backend (server.js)
- `/api/rental-connect/login` now joins tenant_features + features, returns a `features` array of key_names (plus core features always appended) in both the JWT and the JSON response.
- New routes: `GET /api/rc-master/features` (list all), `GET /api/rc-master/tenants/:id/features` (get one tenant's current feature_ids), `PUT /api/rc-master/tenants/:id/features` (replace a tenant's feature set), `DELETE /api/rc-master/tenants/:id` (cascades tenant_features + tenant_users deletion, then drops the tenant's actual database via a root-equivalent connection).

### Frontend
- `tier-gate.js` rewritten: reads `rc_features` (JSON array) from localStorage instead of a plan string. Maps each nav-item's href to a feature key via a lookup table, hides any link whose feature isn't in the tenant's array. Generic "hide empty section header" logic unchanged/still works correctly with the new dynamic source.
- `index.html` (RC tenant login) now stores `rc_features` in localStorage on login.
- `rc-master.html` fully rebuilt: dynamic checklist (grouped by category, core features shown as always-on/disabled checkboxes) replaces the old single plan dropdown for onboarding. Plan dropdown still present as a quick-preset button (applies a sensible default checklist per plan, fully editable before submitting) rather than the sole source of truth. Added "Edit Features" button per tenant in the list (opens a modal, pre-fills their current features, saves via PUT). Added "Delete" button per tenant with a typed-name confirmation prompt (case-sensitive, must match exactly) before calling the delete endpoint.

### Build note: heredoc/paste reliability on mobile SSH
Attempting to transfer rc-master.html via a single base64-encoded line (to avoid quote/backtick escaping issues) caused silent corruption when pasted through the mobile terminal app - resulted in a mismatched-quote syntax error despite base64 containing no special characters, so the failure was almost certainly a long-single-line paste/buffer issue on the mobile client, not a base64/encoding bug. Resolved by reverting to plain multi-line heredocs (same method that worked reliably all session for other files), split into 3 sequential chunks for manageability, and rewriting template-literal-heavy JS into plain string concatenation to minimize fragile characters (backticks, nested escaped quotes) in any single paste. LESSON: avoid extremely long single-line pastes (e.g. base64 blobs) over mobile SSH - prefer normal multi-line heredocs, chunked if the file is large, and validate with `node --check` immediately after each chunk.

Live-tested full CRUD cycle end-to-end: created a test tenant with a custom partial feature set (test2 - Dashboard/Bookings/Block Dates/Units/View Site/Settings only), confirmed correct sidebar gating on actual tenant login, used Edit Features to confirm modal pre-fills correctly, used Delete with correct typed confirmation - verified tenant row, tenant_features rows, and actual rc_tenant_N database were all cleanly removed afterward with no orphaned data.

RC Master Admin is now a complete, working tenant management system: create, configure features per-tenant (fully custom, not just fixed tiers), edit later, and delete - all without any manual SSH/SQL work.

## Session fix (Jun 28) - RC admin sessions never redirected to login on token expiry
Bug: JWT_EXPIRES_IN is 8h (hardcoded in server.js), so tokens did correctly expire server-side, but no RC admin frontend page ever checked for or handled a 401 response - meaning after expiry, pages would just silently fail/show broken or empty data instead of redirecting to login.

Fix: new auth-guard.js - globally patches window.fetch so any 401 response anywhere clears localStorage and redirects to index.html. Added via <script src="auth-guard.js"></script> immediately before the existing tier-gate.js include, across all 18 RC admin pages.

Not yet live-tested against a real 8h expiry (impractical to wait for in-session) - logic verified correct by code review and consistent with the same working pattern already used elsewhere (e.g. Master Admin's own 401 handling). Worth a real-world confirmation next time a session naturally expires.

## Critical fix (Jun 28) - Public tenant website API was using wrong database entirely
Discovered RC tenants DO have a real public-facing website system already built: customer_site_template.html is a reusable template (single TENANT_ID constant to change per deployment), deployed per-tenant as e.g. site-coral.html, hosted via GitHub Pages. Calls 3 public (no-login) API routes: GET /api/public/:tenantId/info, GET /api/public/:tenantId/units, POST /api/public/:tenantId/bookings.

BUG FOUND: all 3 routes were still using the old abandoned shared-pool architecture (pool.query against htm_rentals with tenant_id filtering) instead of the proper getTenantPool/req.db pattern used everywhere else. Concretely broken in two ways:
1. /info queried `SELECT ... FROM tenants WHERE id = ?` against `pool` (htm_rentals) - but the `tenants` table lives in `rc_master`, not `htm_rentals` at all. This call would have failed outright (table doesn't exist) for any real tenant.
2. /units and /bookings queried `units`/`bookings` from htm_rentals filtered by tenant_id - but htm_rentals only ever contains tenant_id=1 (HTM's own data) per earlier audit this session. Coral's real units/bookings live entirely in rc_tenant_2, a separate database pool never touches. Coral's public site would have shown zero units / failed to create bookings, completely silently, despite Coral admin's own settings (website field) correctly pointing to the deployed site-coral.html.

FIX: added a shared `resolveTenant(tenantId)` helper that looks up the tenant's db_name from rc_master.tenants (via masterPool), then all 3 routes use `getTenantPool(tenant.db_name)` for their actual data queries - same correct pattern as every other RC route fixed earlier this session.

Verified fixed: curl tested both GET endpoints live against tenant 2 (Coral) - /info now correctly returns Coral's real settings (property name, branding colors, contact info, the actual GitHub Pages site URL), /units now correctly returns Coral's real unit data from rc_tenant_2 instead of empty/broken results.

IMPORTANT TAKEAWAY: any future new route, especially ones written before tonight's tenant-isolation fix existed as a known pattern, should be checked for this exact bug class (pool vs req.db/getTenantPool) - this was found by manually verifying "is it only 3 routes or more" rather than trusting an assumption, and turned up a real, previously-unnoticed production bug affecting Coral's actual public website.

## Full architecture audit (Jun 28) - confirmed clean
Following the public-website routes bug, did a full audit of every pool.query usage with tenant_id, and every /api/rental-connect/* and /api/public/* route definition, to check for any other instance of the same bug class (RC tenant route incorrectly using shared pool/tenant_id instead of req.db/getTenantPool).

Result: confirmed clean. All remaining pool.query + tenant_id occurrences (hero_images, promotion_gallery, bookings, minibar_items, settings, custom_invoices, promo_banners, staff_salary_log, company_loans, reviews, partners, etc.) belong to HTM's own legacy /api/admin/* routes (lines ~1300-5900), which correctly and intentionally use the shared pool with tenant_id=1 - HTM was never meant to have per-tenant DB isolation, this is by design, not a bug.

Verified zero stray pool.query calls anywhere in the /api/rental-connect/* and /api/public/* route block (lines 6257-6800) - entire block correctly uses req.db/tdb/getTenantPool throughout.

CONCLUSION: the only real bug found was the 3 public website routes (info/units/bookings) documented in the previous entry. No other instances of this bug class exist in the current codebase as of this audit.

## Major fix batch (Jun 28) - RC admin had many entire features non-functional
Following the public-website routes bug, did a UI-by-UI check of every RC admin page and found the majority of pages were either calling /api/rental-connect/* routes that didn't exist at all, or calling old HTM-only /api/admin/* routes. Root cause across all of these: RC admin's frontend was built expecting a complete rental-connect API that was never actually finished on the backend - most of tonight's earlier work only covered Bookings/Invoices/Staff/Settings.

### Routes built from scratch (didn't exist before tonight):
- Minibar (GET/POST/PUT/DELETE), Promotion Gallery, Reviews, Petty Cash - basic CRUD, req.db-based
- Hero Images, Image Upload, Promo Banners - had to match RC's actual schema (cta_text not youtube_url/media_type/button_text on hero_images; image_url not image_filename on promo_banners - RC schema diverged from HTM's, copy-pasting HTM logic doesn't work, always verify actual columns with DESCRIBE first)
- Reports: revenue, expenses, cashflow, occupancy, arrivals, bookings (6 report types) - adapted from HTM versions, removed tenant_id filtering, removed currency_exchanges/partners dependencies (not in RC schema)
- Finance Summary, Revenue CRUD, Monthly Expenses CRUD - finance.html needed a specific nested response shape (summary.revenue.*, summary.cash_flow.*, summary.unit_profits[]) not just flat fields - always check exact frontend consumption code, not just guess a reasonable shape
- Bookings Availability (tenant-scoped) + Block Dates CRUD - CRITICAL finding: the original /api/bookings/availability route had ZERO tenant scoping at all (raw unit_id lookup against shared pool) - a real latent cross-tenant leak risk (didn't manifest only because no live ID collision existed yet between htm_rentals and rc_tenant_2). Fixed with dedicated tenant-scoped route.
- Units full CRUD (POST/PUT/DELETE) - units.html could only ever read units for RC tenants, never create/edit/delete - rate_mvr/rate_usd and original_price_mvr/usd are tracked directly as columns on rc_tenant schemas (no separate unit_rates table like HTM uses)

### Schema mismatches found (RC tenant schema often differs from HTM's, despite similar-looking tables):
- reviews.comment doesn't exist - real column is review_text, also no country column
- hero_images has no youtube_url/media_type/button_text/button_link - has cta_text instead (simpler, image-only)
- promo_banners stores image_url directly (full URL) not image_filename (bare filename + prefix)
- units.amenities and units.gallery_images have a CHECK(json_valid(...)) constraint on rc_tenant schemas - must store as JSON array string, NOT comma-separated like HTM's htm_rentals.units (which has no such constraint) - this caused an update to silently fail with a SQL constraint error, and a fix attempt briefly (accidentally) modified HTM's own /api/admin/units route to also use JSON format, which would have broken HTM - caught and reverted immediately. LESSON: when fixing an RC-specific bug, always grep/verify which exact route (line number, surrounding code) you're patching - HTM and RC routes can look very similar and string-replace can match the wrong one if not scoped precisely.
- htm_rentals has no unit_availability/block_dates distinction issue (HTM stores one row per blocked date in unit_availability); RC schema uses block_dates with start_date/end_date RANGES (one row per range, not per day) - completely different blocking model, required building a date-range-to-individual-dates expansion in the GET route for frontend compatibility.
- units.html sends BOTH rate_mvr/rate_usd (simple per-night rate fields) AND original_price_mvr/usd (separate "original/discount price" fields) - the route's fallback logic needs `(original_price_mvr || rate_mvr) || null` not an undefined-check, since the frontend always sends original_price as explicit null (not omitted) when that field is empty, which defeats a !== undefined check.

### Other concrete fixes:
- staff-payroll.html had its closing </body> auto-guard/tier-gate script insertion accidentally land INSIDE a JS template literal building printable payslip HTML (which itself contains a literal </body></html> string) - browser's HTML parser terminated the real script block early on the literal </script> text, causing raw JS to render as visible page text. Removed the erroneous duplicate tags from inside the print template; confirmed via automated check that no other of the 18 files had the same duplication.
- /api/rental-connect/units GET was missing `success: true` in its response - block-dates.html (and likely others) checked `if (data.success)` before populating, so the unit dropdown silently never populated despite the data being correct.

### Calendar enhancement
- calendar.html had a `blockedDates` variable and `.cal-event.blocked` CSS class already present but never wired to an actual fetch call - blocked dates were planned but never connected. Added fetch to bookings/availability endpoint and rendering logic (🚫 marker) to calendar day cells.

This was a large fix batch - RC admin went from "looks complete in the UI but most buttons silently do nothing for a real tenant" to actually functional end-to-end for a guesthouse-tier tenant (Coral). Recommend a final full pass logging in as Coral and clicking through every single page/action before considering RC admin genuinely done, since this session found this many gaps through fairly cursory testing - more may exist.

## Infrastructure decision needed: server upgrade for custom domains + guest site hosting (Jun 28)
Discussed building proper custom-domain support for RC tenants (host guest-facing websites + handle SSL on Lightsail directly, Host-header-based tenant routing, NOT GitHub Pages per-tenant repos - decided against that approach since it doesn't scale cleanly, requires a new repo per tenant indefinitely).

Current instance specs confirmed: htm-rentals-backend on Lightsail, 512MB RAM / 2 vCPUs / 20GB SSD, Singapore region (ap-southeast-1a), running on a Bitnami Node.js blueprint that is being DEPRECATED (no updates after May 19 2026, no new instances on this blueprint after Nov 19 2026 - existing instances keep running fine, but worth tracking for long-term planning).

This instance is already tight on memory (confirmed earlier this session - only 17MB free before swap was added). Adding Nginx + Certbot (SSL automation for custom domains) + actually hosting guest-facing tenant websites (currently on GitHub Pages, NOT this server) would meaningfully increase load beyond what 512MB can reasonably handle.

Lightsail does NOT support in-place resize for this instance - upgrading requires: (1) create a snapshot of current instance, (2) launch a new larger instance from that snapshot, (3) reattach/repoint the static IP to the new instance so DNS doesn't need to change, (4) test thoroughly, (5) only then decommission the old instance.

DECISION NEEDED before starting custom-domain/guest-site-hosting work: what size to upgrade to. Not yet decided. This should be treated as its own dedicated session/task - a full server migration, done carefully, not a quick mid-session change.

ALSO WORTH DECIDING: whether to migrate off the deprecated Bitnami blueprint at the same time (cleaner long-term, but means rebuilding Node/MySQL/PM2 setup from scratch rather than carrying it over via snapshot) vs. just resizing within the same Bitnami blueprint for now (faster, snapshot carries everything over, defer the blueprint-migration decision to later).

## Build sequencing (revised, Jun 28 late session)
Given the infrastructure question, suggested order for next sessions:
1. Guest-facing booking flow (unit detail page, public availability calendar, instant-confirmed booking + auto-invoice + email, currency toggle) - can be built on the CURRENT instance, using the existing GitHub Pages + TENANT_ID template pattern, no new infra needed. This delivers the actual core "guests can see availability and book instantly" value proposition discussed tonight as RC's key differentiator.
2. Server upgrade (snapshot -> new larger instance) - dedicated session, decide target size first.
3. Custom domain infrastructure (Nginx, Certbot, Host-header tenant routing, migrate guest sites off GitHub Pages onto the upgraded Lightsail instance) - build only after step 2 is done, since this is the heavier-load feature that justified the upgrade in the first place.

Rationale: don't block the core booking-flow value (item 1) on an infrastructure decision/migration (items 2-3) that doesn't need to happen first - ship the differentiator, then invest in the custom-domain premium feature once there's a solid server foundation under it.

## Session 8 (Jul 2) - Guest-facing booking flow + design system + unit editor rebuild (MAJOR session)

### New public API routes (all resolveTenant + getTenantPool pattern)
- GET /api/public/:tenantId/hero-images, /promo-banners, /reviews - wired into customer_site_template.html (loadHero/loadPromos/loadReviews; sections hidden when empty, hero keeps static fallback)
- GET /api/public/:tenantId/units/:unitId - full unit detail (parses amenities/gallery_images JSON server-side)
- GET /api/public/:tenantId/units/:unitId/availability - narrow public-safe blocked ranges (block_dates ranges + pending/confirmed bookings, no PII)

### CRITICAL FIX - public bookings route was broken in production
POST /api/public/:tenantId/bookings referenced booking_reference column which does NOT exist on rc_tenant schemas (HTM-only column). Every guest booking failed. Fixed: column removed from INSERT, WEB-XXX ref now folded into special_requests as [Ref: ...]. NOTE: route still inserts booking_status='pending' - instant-confirm checkout flow NOT built yet (biggest open item).

### Homepage template restructure
- Booking form + map removed from homepage entirely; unit cards now link to unit-detail.html?id=N via "View Details"
- Dead JS removed (calcPrice/submitBooking/b-unit dropdown)

### unit-detail.html - built from scratch, then fully rebuilt (640 lines, 3-chunk heredoc)
Final feature set:
- Sticky Local/Foreign currency toggle bar (MVR/USD) - drives all pricing displays + NID field visibility (NID folded into special_requests as [NID: ...])
- Specs table (HTM-style rows): Guests/Bedroom/Beds/Bathroom + privacy suffixes + Kitchen/Living/Balcony rows (conditional)
- Price card: rate headline (desktop only), DIRECT BOOKING badge, calendar, date fields, booking form all in one card
- Calendar: exact HTM tap logic port (single tap = checkin+auto next-day checkout, second tap extends with booked-range validation, same-tap clears, third tap restarts). States: past=plain gray, future booked=red strikethrough number on white, today=teal outline+glow (today+booked=teal outline red number)
- Date fields: readonly display boxes under calendar (CHECK-IN 14:00 / CHECK-OUT 12:00), short month format, ISO stored in dataset.iso
- Adults/Children dropdowns respecting max_adults/max_children/max_guests interplay
- Amenities "Show all N" collapse (6 visible), description "Show more" collapse, trust line "You won't be charged yet"
- Bottom sticky bar: navy top border, compact Inter-bold price, switches to total+nights when dates selected, Book This Unit scrolls to calendar
- Photo badge = unit_number; teal line = building_name (fallback property_name from /info); title = unit_type_label fallback 'Apartment'
- Map: hybrid render priority - map_image+link > lat/lng Google embed > link-only. Get Directions pill opens map_link or dir API with coords
- Responsive: mobile single column, tablet constrained, desktop 2-col with sticky right rail (price-bar hidden)

### RC guest design system (agreed, documented in session)
Navy #0A2540 structure, teal #40B5AD single accent, charcoal-on-white body text (no gray-on-gray), warm white bg, Playfair titles only, Inter 16px+ body, 44px touch targets, 1100px max content, one shadow/radius scale. Applied to unit-detail fully. Homepage template NOT yet restyled to it (open item).

### units schema additions (rc_tenant_2 AND rc_tenant_3 both altered; future tenants inherit via clone)
bedroom_privacy, bathroom_privacy, kitchen_desc, living_desc, balcony_desc, map_lat, map_lng, map_image, map_link

### unit-edit.html - NEW full-page sectioned editor (replaces buggy modal in units.html)
- Sections: Basics (incl Parent Unit dropdown - was silently dropped in first version, restored), Rooms & Capacity, Spaces, Location, Photos, Amenities, Pricing & Offers, OTA Links
- Full-state saves (backend PUT/POST rewritten: no more COALESCE partial updates - root cause of "fields blank on edit" and the amenities='' JSON constraint bug, BOTH FIXED)
- New backend route GET /api/rental-connect/units/:id (list route returns slim subset, edit page needs full row)
- Photos: upload via /api/rental-connect/upload-image (returns {success,url}), featured tap-select, left/right reorder arrows (no drag-drop on mobile)
- Amenities: preset checklist + custom add, stored as real JSON array
- Location: Leaflet picker, Carto Voyager tiles default (Google-like clean look) + Esri satellite toggle, draggable pin + tap-to-place fills lat/lng; PLUS Google Maps Link field + Map Display Image upload (HTM pattern - image+link takes display priority on guest page)
- units.html Add/Edit buttons now link to unit-edit.html; old modal code left as dead code (cleanup later)

### Link resolution research (for future reference)
share.google links resolve to Search pages (no coords). maps.app.goo.gl resolves to place URLs WITHOUT coords when shared from app; page HTML is consent-walled for datacenter IPs (returns Singapore edge coords). Conclusion: server-side link->coords resolution unreliable, hence image+link hybrid. Airbnb uses Google Places autocomplete + draggable pin (needs paid API key - deliberate future decision).

### Known CDN gotcha discovered
GitHub Pages CDN serves different file versions from different edge nodes for extended periods (server's Singapore edge vs phone's edge showed different commits simultaneously). Cache-bust via query param unreliable; pushing any commit eventually converges. Argument for eventual Lightsail+Nginx tenant site hosting (existing infra decision doc).

### Verified working end-to-end this session
Hero/Promo/Reviews on Coral site; unit detail full flow; calendar with real blocked dates; MVR/USD toggle; test bookings via curl AND via UI form (success message confirmed); unit editor round-trip save/reload; map data saved to DB and flowing through public API (guest render pending CDN convergence at session end - verify next session).

### OPEN ITEMS (priority order)
1. CHECKOUT FLOW - the core differentiator, NOT started: instant-confirm booking (currently 'pending'), auto-invoice via generateTenantInvoicePDF, guest confirmation email. Deserves dedicated session.
2. Verify map renders on guest page (CDN was converging at session end)
3. Homepage template restyle to design system (unit-detail is the reference)
4. site-coral.html regenerate from updated template (last regenerated mid-session - hero/promo/reviews included but NOT the later template changes; check diff)
5. "Getting Here" free-text field per unit (ferry/speedboat info - serves outer islands better than maps)
6. AI description generator for units (discussed, never existed, DeepSeek widget still in old backlog)
7. Cleanup: dead modal code in units.html, unused unit_type column, stale .bak files in repo dir
8. Geolocate-on-open for Leaflet picker (discussed, not built)

### Session lessons
- Inline python3 heredocs with long exact-match strings get corrupted by mobile terminal paste (multiple silent MISSes) - ALWAYS check APPLIED/MISS output; prefer cat-to-file + sed line-number inserts for anything over ~10 lines
- bash history expansion ate a heredoc again (echo with <\!-- -->) - set +H or avoid ! entirely

## Session 8 continuation - Guest site migrated to Lightsail

### Guest site now served from Lightsail (NOT GitHub Pages)
- New folder: ~/rental-connect-guest/ served via Express at api.htmrentals.com/guest/
- Added app.use('/guest', express.static('/home/bitnami/rental-connect-guest')) at line 794 of server.js
- Files: unit-detail.html, site-coral.html, customer_site_template.html
- Coral settings.website updated to https://api.htmrentals.com/guest/site-coral.html
- Instant deploys: edit in ~/rental-connect-admin/, run ~/sync-guest.sh to push live
- GitHub Pages still exists as backup but no longer the primary guest site

### Currency mode per unit
- New column: units.currency_mode ENUM('both','mvr_only','usd_only') DEFAULT 'both'
- Added to both rc_tenant_2 and rc_tenant_3
- Unit editor: Currency Toggle dropdown in Basics section
- Guest page: hides Local/Foreign toggle bar when mvr_only or usd_only, sets correct default currency
- Back button separated into its own back-bar div (always visible regardless of currency mode)

### Map hybrid implementation complete
- map_image + map_link fields on units table (both tenant DBs)
- Unit editor: Upload Map Image button + Google Maps Link field in Location section
- Guest page render priority: image+link > lat/lng embed > link only > "Location not set"
- Leaflet picker (Carto Voyager tiles + Esri satellite toggle) for coordinate input
- Data verified working: map_image and map_link saving and flowing through public API

## Session 8 final batch (Jul 3 early AM)

### Guest site fully migrated to Lightsail
- ~/rental-connect-guest/ served at api.htmrentals.com/guest/
- sync-guest.sh script for pushing admin edits to live guest folder
- No more GitHub Pages dependency for guest sites

### Booking flow split into two pages
- unit-detail.html: pure information page (gallery, specs, description, amenities, location)
- book.html: dedicated booking page (unit summary card, calendar, form, trust signals)
- Book Now in bottom bar links to book.html?id=N

### Currency mode per unit
- ENUM('both','mvr_only','usd_only') on units table
- Toggle bar shows/hides tabs based on mode
- Both pages respect currency_mode

### Known issues to fix next session
- "Unit not found" briefly flashes on unit-detail before JS loads (error div timing)
- Price shows "—" on unit-detail bottom bar (JS functions removed with price-card)
- map render still shows "Loading location..." (map_image/map_link in DB but render logic may need re-check)
- book.html TENANT_ID hardcoded to 2 - needs to be dynamic per deployment
- site-coral.html not updated to reflect new book.html flow yet

## Session 8 continued (Jul 3) - Guest site fixes + booking flow split

### All fixes applied to ~/rental-connect-guest/ (Lightsail-served, instant deploy)
- unit-detail.html and book.html are the live guest files
- sync-guest.sh copies from rental-connect-admin to rental-connect-guest
- NOTE: rental-connect-admin versions are now OUT OF SYNC with guest versions
  (many fixes applied directly to rental-connect-guest after the cp)
  Next session: reverse-sync guest->admin or treat rental-connect-guest as source of truth

### Booking flow split complete
- unit-detail.html: info only (gallery, specs, desc, amenities, location, map)
- book.html: dedicated booking page (unit summary, calendar, form)
- Book Now button in bottom bar links to book.html?id=N&cur=MVR/USD
- Currency carried via URL param, respected on book page

### currency_mode per unit - fully working
- unit-detail: hides/shows Local/Foreign tabs via CSS data-mode attribute
- book.html: respects currency_mode (mvr_only/usd_only overrides URL param, both respects it)
- Fixed: id="curr-bar" was missing from unit-detail HTML causing mode hiding to fail

### unit-detail fixes
- "Unit not found" flash fixed (error div explicitly hidden in renderUnit)
- Price bar "—" fixed (renderPricing guarded against null unitData + missing price-headline)
- Map rendering fixed (populateGuestDropdowns crashed on missing b-adults/b-children elements)
- Silent JS errors fixed: renderCalendar guarded for missing cal-grid, setCurrency guarded for missing nid-row, calcPrice call removed from detail page setCurrency
- renderUnit crash: populateGuestDropdowns referenced removed booking form elements
- Gallery: removed nav arrows, added touch swipe (50px threshold, left=next, right=prev)

### Amenities + Description - bottom sheet modals (HTM-style)
- "Show more" on description opens bottom sheet (slides up, 85vh max)
- "Show all N amenities" opens full amenities sheet
- Consistent pill styling in sheet matching detail page pills
- Amenity icon map expanded to 30+ keywords, switched to ordered array for correct priority
  (longer/more specific strings matched first - fixes washing machine vs washer conflict etc)
- Sheet close: small borderless X, no circle

### Known issues / open items
- rental-connect-admin unit-detail.html is stale vs rental-connect-guest version
  (admin version still has booking form, old icon map, old currency handling)
- book.html not in rental-connect-admin at all (only in rental-connect-guest)
- site-coral.html not updated to remove dead booking form JS
- TENANT_ID hardcoded in both guest files (=2 for Coral)
- Packages feature (Room Only/BB/HB/FB/AI) discussed but not built yet
- House rules field discussed but not built yet
- Checkout flow (instant-confirm + invoice + email) still the biggest open item

## Session 9 (Jul 5) - HTM fixes + RC packages + checkout flow completion

### HTM critical bug fixes
- FIXED: "Request to Book" was crashing with `b is not defined` at line 1531
  Root cause: variables `total_amount` and `total_nights` not in destructured body of /api/bookings/create
  Fix: use `rates[0].nightly_rate` directly instead of referencing undefined `b`
- FIXED: Invoice not attaching to HTM confirmation email
  Root cause: slip upload route (/api/bookings/:id/slip) INSERT into invoices used `req.tenant_id`
  which is undefined on public routes — `tenant_id` column is NOT NULL with default 1
  Fix: hardcode tenant_id=1 for HTM invoices (line 3887)
- Both bugs introduced by commit 540f289 ("Auto-create invoices on booking confirmation")

### RC checkout flow completed
- book.html → redirects to checkout.html with all params in URL (no booking created yet)
- checkout.html: booking summary, bank accounts (from tenant settings), slip+ID upload, email, confirm
- Public upload route: POST /api/public/:tenantId/upload
- Public documents route: POST /api/public/:tenantId/bookings/:bookingId/documents
- Booking created as confirmed at checkout submit (not at book page)
- Invoice auto-generated, PDF attached to confirmation email
- badgeX bug fixed in generateTenantInvoicePDF (was inside wrong scope)
- PDF footer fixed: split into two clean lines (name+address / email+phone)
- Payment message updated: "If any concerns we will contact you directly"
- Booking reference = invoice number (consistent)
- Email subject includes reference number (prevents Gmail threading)

### RC packages feature built
- Schema: unit_packages table (id, unit_id, name, description, price_per_person_mvr, price_per_person_usd, is_active, sort_order) on rc_tenant_2 and rc_tenant_3
- Backend routes: GET/POST public packages, GET/POST/PUT/DELETE admin packages
- unit-edit.html: Packages section with add/edit/delete rows, saves on unit save
- unit-detail.html: Package cards (select to highlight, info button opens sheet, bottom bar updates with addon price per night)
- book.html: Package selector pre-populated from URL param, price recalculates with package addon per adult
- checkout.html: Shows selected package in booking summary
- Invoice line item includes package name (e.g. "One Room Apartment — Bed & Breakfast")
- Calculation: (room_rate + package_price_per_person × adults) × nights = total

### RC guest site (Lightsail-served)
- Files in ~/rental-connect-guest/ — instant deploy, no GitHub Pages
- rental-connect-admin versions still need syncing after this session

### OPEN ITEMS
- HTM: booked dates not crossing out on calendar (reported, not investigated yet)
- RC: packages UI testing not completed (backend was down during test)
- RC: rental-connect-admin files out of sync with rental-connect-guest
- RC: TENANT_ID hardcoded in guest files (=2)
- RC: site-coral.html needs updating
- RC: Homepage template restyle to design system
- RC: House rules field per unit

## Session 9 continued - Per-tenant subdomain routing

### Architecture implemented
- resolve endpoint: GET /api/public/resolve/:slug → returns tenant_id + settings
- Guest files no longer hardcode TENANT_ID=2
- Each file loads /tenant.js first (silent 404 if not found)
- Falls back to ?tenant= URL param, then 'coral' default
- resolveTenantId() called before any API requests

### coral.api.htmrentals.com live
- DNS: coral.api A record → 13.212.34.47 (Namecheap)
- SSL: Let's Encrypt cert via certbot (expires 2026-10-03, auto-renews)
- Apache vhost: /opt/bitnami/apache/conf/vhosts/coral-vhost.conf
- tenant.js: ~/rental-connect-guest/coral/tenant.js (sets RC_TENANT_SLUG='coral')
- Coral settings.website updated to https://coral.api.htmrentals.com/site-coral.html

### Adding a new tenant (template)
1. Create ~/rental-connect-guest/SLUG/tenant.js with RC_TENANT_SLUG='SLUG'
2. Copy coral-vhost.conf → SLUG-vhost.conf, update ServerName
3. Add DNS A record: SLUG.api → 13.212.34.47
4. certbot certonly --webroot -w /home/bitnami/rental-connect-guest -d SLUG.api.htmrentals.com
5. Add HTTPS block to vhost with new cert paths
6. sudo apachectl graceful
