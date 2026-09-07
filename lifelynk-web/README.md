# LifeLynk AI — Government Dashboard — Completed

This package completes the Government dashboard using the existing LifeLynk schema. No new tables are introduced and emergency monitoring uses `public.emergency_sos` as the source of truth.

## Included

- Organization verification / rejection workflow
- Audit logging and admin notification on verification decisions
- National blood inventory and blood-group breakdown
- Supply-vs-demand shortage detection
- Low-stock, expired and next-7-days expiry risk analytics
- Blood request analytics
- Donor availability analytics
- Donor activity from `donation_history`
- Province-level network monitoring
- City-level network monitoring
- Facility/network health indicators
- Detailed SOS monitoring from `emergency_sos`
- Government alerting
- Stored historical metrics from `government_analytics` when records exist
- Secure server-side verification action
- Responsive UI

## Install

Copy these files into the existing project, preserving their paths.

Run `supabase/government-dashboard.sql` in the Supabase SQL Editor first.

Then from the project root:

```powershell
npm run lint
npx tsc --noEmit
npm run build
npm run dev
```

Open `/government` while signed in as `GOVERNMENT_ADMIN` or `SUPER_ADMIN`.

## Important

The data loader calculates live government metrics from the existing source tables. `government_analytics` is displayed only when historical records are already present; the package does not invent or create historical data.

The expiry warning uses the existing `blood_inventory.expiry_date` and treats the next 7 days as the operational warning window.
