# HTM Rentals + Rental Connect Status

## Infrastructure
- Backend: AWS Lightsail 13.212.34.47, Node.js/Express, PM2
- RC Admin: Served from Lightsail at https://api.htmrentals.com/admin/
- HTM Rentals frontend: GitHub Pages at htmrentals.com
- DB: MySQL htm_rentals (htm_user)

## Tenants
- Tenant 1: bissbro (HTM Rentals)
- Tenant 2: coral_admin (Coral Guesthouse) - password: i1love4AllaH3@#

## Rental Connect — Done
- Full admin panel served from Lightsail (no cache issues)
- All pages desktop-first layout with organized sidebar
- Bookings, Units, Invoices, Calendar, Settings
- Leads, Experiences, Block Dates, Petty Cash (rebuilt)
- Staff Payroll (rebuilt with full payslip PDF generator)
- Reports, Finance, Minibar, Hero Slides, Promo Banners, Reviews
- Property type setting (apartment vs guesthouse)
- Guesthouse: property rent, simplified expense categories
- Finance summary updates after all save/delete operations
- View Site link from settings
- RC admin auto-creates invoice + revenue on booking confirmation

## Security — Done
- All routes scoped by tenant_id
- Verified: bookings, invoices, units, leads, experiences
- Verified: petty cash, minibar, hero slides, promo banners, reviews
- Verified: reports (revenue, expenses, cashflow, occupancy, bookings)
- Verified: finance summary, per-unit cashflow
- Partners and loans removed from RC (HTM-specific)

## Pending
- Dashboard live stats
- OTA channel iCal links in settings
- Invoice number scoped per tenant
- Coral Guesthouse full onboarding with real data
- DeepSeek guest chat widget (last)

## Key Files
- Backend: ~/htm-rentals-backend/server.js
- RC Admin: ~/rental-connect-admin/*.html
- RC served at: https://api.htmrentals.com/admin/
- Backups: ~/htm-rentals-backend/server.js.bak.*
