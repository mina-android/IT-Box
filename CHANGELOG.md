# Changelog

All notable changes to Inventorya are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added
- **Import Devices** — Import Laptops, Network Devices, MiFis, Printers, Electronics, Employees, Bills, Email Accounts from Excel (.xlsx) with Append or Replace mode
- **Import Expenses** — Import expense records from Excel with Append or Replace mode
- **Import service** (`ExcelImportService`) — handles date normalization (yyyy-MM-dd, dd MMM yyyy, Excel serial), skips header/total rows, validates categories, reports per-row errors

---


## [1.0.0] — 2026-05-15

### Added
- **Onboarding screen** — First-launch prompt for company name; displayed in Inventory tab header
- **Bills tab** — Track recurring bills by category (MiFis, 4G Internet, Landline Internet, Landline Phone, Mobile Phone) with person, number, price, and notes
- **Emails tab** — Email accounts linked to employees with password show/hide
- **MiFis tab** — Dedicated MiFi device management inside Inventory with quota, WiFi, gateway, admin credentials, and borrow tracking
- **Borrow tracking for MiFis and Electronics** — Replaced Network device borrowing with Electronics + MiFis
- **Expenses year filter** — Year selector in AppBar to filter expense view
- **Expenses Export (date range)** — From/To date picker exports selected range to Excel (.xlsx)
- **Export Devices** — Per-category Excel export for all device tables
- **Company name in Settings** — Edit company name anytime; reflected live in Inventory tab title
- **Backup to file manager** — Uses Android SAF (Storage Access Framework) to let user choose save location
- **Dark mode** — Enabled by default, persisted via SharedPreferences
- **Fast page transitions** — `FadeUpwardsPageTransitionsBuilder` for snappier navigation
- **Label PDF export** — 3-column device label sheet (matches physical label format) for all categories
- **Settings screen** — Accessible from every top-level screen via AppBar settings icon

### Changed
- **Assigned user in Laptop form** — Now selects from Employees list instead of free-text
- **Borrow device types** — Changed from "Network / Electronic" to "Electronic / MiFi"
- **Bills** — Date field completely removed from Bills (not needed for simple entry tracking)
- **Currency** — All monetary values display as EGP throughout Expenses and Bills
- **Navigation** — Restructured to 6 bottom tabs: Borrowed, Expenses, Employees, Inventory, Bills, Emails
- **Inventory sub-tabs** — Full-width equal tabs: Laptops, Network, MiFis, Printers, Electronics
- **Network Devices fields** — Removed `user_or_location`; added WiFi Name, WiFi Password, Gateway, Admin Password
- **Borrow cards** — Compact layout removing wasted space

### Fixed
- Items not showing after adding without app restart (Scaffold+FAB pattern per screen)
- Bills screen stuck on loading (was querying `ORDER BY date DESC` on a removed column)
- Status bar overlap on Expenses and Employees screens (added AppBar)
- Input suggestion popups across all form fields (`enableSuggestions: false`)
- Backup showing "saved" message even when user cancelled the file picker

### Technical
- Database schema version: **5**
- Migrations: v1→v2 (network_devices rebuild), v2→v3 (mifis.status column), v3→v4 (bills, email_accounts tables), v4→v5 (bills date column removed)
- `ThemeService` and `CompanyService` converted to singletons
- All `withOpacity()` calls replaced with `withValues(alpha:)` (Flutter 3.27+ requirement)
- All form `TextFormField`s set `enableSuggestions: false, autocorrect: false`
- All `if`/`for`/`while` control flow enclosed in `{ }` blocks
- `DropdownButtonFormField` replaced with `InputDecorator + DropdownButton` (deprecated `value:` param)

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.0.0 | 2026-05-15 | Initial release — full inventory, borrow, expenses, bills, emails, export |
