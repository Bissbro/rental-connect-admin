# Rental Connect Status

## Infrastructure
- Backend: AWS Lightsail 13.212.34.47, Node.js/Express, PM2
- RC Admin: https://api.htmrentals.com/admin/
- HTM Rentals frontend: GitHub Pages at htmrentals.com
- Master DB: rc_master (tenants + users)
- Tenant 1 DB: rc_tenant_1 (HTM Rentals)
- Tenant 2 DB: rc_tenant_2 (Coral Guesthouse)

## Architecture
- Multi-tenant via separate databases (not tenant_id columns)
- Login → rc_master.tenant_users → JWT contains db_name
- requireAuth sets req.db = getTenantPool(db_name)
- All RC routes use req.db — impossible to cross-contaminate

## Tenants
- Tenant 1: bissbro / i1love4AllaH3@# → rc_tenant_1
- Tenant 2: coral_admin / i1love4AllaH3@# → rc_tenant_2

## RC Admin Pages (all complete)
- dashboard, bookings, leads, block-dates, calendar
- units, minibar, invoice, finance, reports, petty-cash
- staff-payroll, hero-slides, promo-banners, reviews
- experiences, settings, index (login)

## Key Features Done
- Separate DB per tenant — zero data leak risk
- Invoice + revenue auto-created on booking confirm
- Payslip PDF (PDFKit, clean design)
- Property type setting (apartment vs guesthouse)
- Finance page adapts to property type
- Block dates via RC routes → block_dates table
- Settings per tenant in tenant DB

## Pending
- Dashboard live stats
- RC admin — remaining routes audit for req.db consistency
- Finance/reports routes need req.db migration
- OTA iCal sync per tenant
- Coral Guesthouse full onboarding
- DeepSeek guest chat widget (last)

## Key Files
- Backend: ~/htm-rentals-backend/server.js
- RC Admin: ~/rental-connect-admin/*.html
- Backups: ~/htm-rentals-backend/server.js.bak.*
