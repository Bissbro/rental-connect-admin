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
