# Inventorya — Claude Context File

This file helps Claude (and other AI assistants) understand the Inventorya codebase quickly in a new conversation.

---

## What This App Is

**Inventorya** is an Android Flutter inventory management app for companies. Package: `com.ma.inventorya`. It uses a local SQLite database (no cloud, no auth). The UI is Material You with dark mode on by default.

---

## Architecture at a Glance

```
Single Flutter project → Android target only (as of v1.0.0)
Local SQLite (sqflite) → DatabaseHelper singleton
ThemeService singleton → dark/light, SharedPreferences
CompanyService singleton → company name, onboarding flag
No state management library → setState + async/await throughout
```

---

## Navigation Structure

```
HomeScreen (NavigationBar — 6 tabs)
├── BorrowedScreen          — active/history tabs, FAB → AddBorrowScreen
├── ExpensesScreen          — year filter in AppBar, monthly grouping
├── EmployeesScreen         — list + add/edit/delete
├── InventoryScreen         — TabBar (5 sub-tabs, NOT scrollable, isScrollable:false)
│   ├── LaptopsScreen
│   ├── NetworkDevicesScreen
│   ├── MiFisScreen
│   ├── PrintersScreen
│   └── ElectronicsScreen
├── BillsScreen             — category chips (Wrap), loading uses try/catch
└── EmailsScreen            — employee-linked email + password
```

Every list screen has its **own Scaffold + FloatingActionButton** so adding items refreshes immediately without restarting.

---

## Database

**File:** `inventorya.db` — SQLite via `sqflite`  
**Helper:** `lib/database/database_helper.dart` — singleton (`factory DatabaseHelper() => _i`)  
**Current version:** 5  
**Migration pattern:** `onUpgrade` switch on `old < N`

### Tables

| Table | Notable columns |
|-------|----------------|
| `laptops` | laptop_number, model, cpu, gpu, ram, storage, condition, user, password |
| `network_devices` | device_number, model, phone_number, device_location, service_provider, wifi_name, wifi_password, gateway, admin_password, **status** |
| `mifis` | device_number, model, phone_number, wifi_name, wifi_password, quota, service_provider, gateway, admin_password, **status** |
| `printers` | printer_number, model, condition, location |
| `electronics` | device_number, device_name, details, **status** |
| `employees` | name, phone_number |
| `borrow_logs` | device_type ('electronic'\|'mifi'), device_id, device_name, device_number, employee_id, employee_name, reason, out_date, back_date, is_returned |
| `expenses` | date (yyyy-MM-dd), item, price (REAL), details |
| `bills` | person, number, category, price (REAL), notes — **no date column** |
| `email_accounts` | employee_id, employee_name, email, password |

### Status field
Only `network_devices`, `mifis`, and `electronics` have a `status` column (`'Available'` | `'Borrowed'`). `borrow_logs.device_type` is only `'electronic'` or `'mifi'` — Network Devices are NOT borrowable.

---

## Key Services

### `ThemeService` (`lib/services/theme_service.dart`)
- Singleton factory
- Stores `dark_mode` bool in SharedPreferences
- Default: dark = `true`
- Call: `ThemeService().toggle()` or `ThemeService().isDark`

### `CompanyService` (`lib/services/company_service.dart`)
- Singleton factory
- Stores `company_name` String and `onboarding_done` bool
- Must call `await CompanyService().load()` in `main()` before `runApp`
- `CompanyService().name` used in InventoryScreen AppBar title

### `ExcelService` (`lib/services/excel_service.dart`)
- Static methods only
- Uses `excel` package to build `.xlsx` files
- Uses `share_plus` to open system share sheet
- `ExcelService.exportTable(...)` — generic table export
- `ExcelService.exportExpenses(...)` — expenses with total row

### `LabelService` (`lib/services/label_service.dart`)
- Static `printLabels(labels, title, context)` 
- Uses `pdf` package to build 3-column label PDF
- Saves to temp dir, shares via `share_plus`

---

## Shared Widgets (`lib/widgets/common_widgets.dart`)

| Widget/Function | Purpose |
|----------------|---------|
| `StatusBadge(status)` | Green "Available" / Orange "Borrowed" pill |
| `ConditionBadge(condition)` | Good/Fair/Poor colored badge |
| `IconBox(icon, color, size)` | Rounded square icon container |
| `EmptyState(icon, title, subtitle)` | Centered empty placeholder |
| `SearchBar2(controller, hint)` | Styled search field with enableSuggestions:false |
| `DetailRow(label, value, icon)` | Key-value row for detail sheets |
| `SectionLabel(text)` | Bold section header in forms |
| `showConfirmDialog(context, ...)` | AlertDialog returning Future<bool> |
| `showSnack(context, message, error)` | Floating SnackBar, green or red |

---

## Form Screens Convention

All form screens follow this pattern:
- `AppBar` with title only — **no Save button in AppBar** (removed intentionally)
- Bottom `ElevatedButton.icon` with `Icons.save_outlined`
- All `TextFormField` have `enableSuggestions: false, autocorrect: false`
- `try/catch/finally` in `_save()` with `if (!mounted) return` after every `await`
- `Navigator.pop(context, true)` on success → parent calls `_load()`
- Dropdowns use `InputDecorator + DropdownButton` (NOT `DropdownButtonFormField` — deprecated `value:` param)

---

## Bills Screen — Known History

The `bills` table **does not have a `date` column**. It was removed in DB v5. If you ever touch the `getBills()` query, do NOT add `orderBy: 'date DESC'` — it will crash with a silent SQL error causing infinite loading. Use `orderBy: 'id DESC'` instead.

---

## App Icon

- **Source:** `assets/icon/app_icon.png` (3464×3464 RGBA PNG)
- **Adaptive margin:** 42dp on a 108dp canvas
- **Generated sizes:** mdpi→xxxhdpi for both `ic_launcher` and `ic_launcher_round`
- **Adaptive foreground:** `ic_launcher_foreground.png` in each mipmap folder
- **Background color:** `#FFFFFF` (white) in `colors.xml`
- **Splash color:** `#1A2050` (dark navy)

---

## Build Info

```yaml
compileSdk: 36
minSdk: 31          # Android 12+ (required for material3 lStar attr)
targetSdk: 36
ndkVersion: 28.2.13676358
AGP: 8.6.0
Kotlin: 2.1.0
Gradle: 8.9
Java target: 17
```

---


## Import System (`lib/services/excel_import_service.dart`)

- Static class `ExcelImportService`
- `pickExcel()` — opens file picker for `.xlsx`, returns `Excel?`
- One method per category: `importLaptops`, `importNetworkDevices`, `importMiFis`, `importPrinters`, `importElectronics`, `importEmployees`, `importBills`, `importEmailAccounts`, `importExpenses`
- All methods return `ImportResult(inserted, skipped, errors[])`
- Row 0 is always the header — skipped automatically
- Column 0 is always the `#` row number — skipped automatically
- `_normalizeDate()` handles: `yyyy-MM-dd`, `dd MMM yyyy`, Excel serial dates
- Bills import validates category against `Bill.categories` list (case-insensitive)
- Email import skips rows where password is `(hidden)` (exported placeholder)
- Expenses import skips rows where col 0 is `TOTAL` (the summary row ExcelService adds)
- Import mode: **Append** (add to existing) or **Replace** (delete table first, then import)

## Common Pitfalls

1. **Bills stuck loading** — always check `getBills()` orderBy doesn't reference `date`
2. **New item not showing** — every list screen must have its own `Scaffold + FAB`, not rely on `HomeScreen` FAB
3. **withOpacity deprecated** — use `.withValues(alpha: x)` not `.withOpacity(x)`
4. **DropdownButtonFormField** — use `InputDecorator + DropdownButton` to avoid deprecation warning
5. **BuildContext across async gap** — always `if (!mounted) return;` after any `await`
6. **Database version** — always bump version number and add `if (old < N)` block when changing schema
7. **Bills date** — does not exist in DB or model; do not add it back
