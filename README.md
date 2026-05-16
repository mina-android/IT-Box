<p align="center">
  <img src="assets/icon/app_icon.png" width="120" alt="Inventorya Logo"/>
</p>

<h1 align="center">Inventorya</h1>

<p align="center">
  A comprehensive inventory management Android app built with Flutter.
  <br/>
  Manage laptops, network devices, MiFis, printers, electronics, employees, bills, expenses, and email accounts — all in one place.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Android-API%2031%2B-green?logo=android" />
  <img src="https://img.shields.io/badge/License-MIT-yellow" />
  <img src="https://img.shields.io/badge/Version-1.0.0-purple" />
</p>

---

## Features

### Inventory Management
| Tab | Description |
|-----|-------------|
| **Laptops** | Track laptops with full specs (CPU, GPU, RAM, Storage), condition, and assigned employee |
| **Network Devices** | Routers with WiFi credentials, gateway, admin password, and borrow status |
| **MiFis** | Mobile WiFi devices with quota, credentials, and borrow status |
| **Printers** | Printers with condition and location tracking |
| **Electronics** | General electronic devices with borrow tracking |

### People & Communication
| Tab | Description |
|-----|-------------|
| **Employees** | Employee directory with name and phone number |
| **Emails** | Email accounts linked to employees with password manager |

### Operations
| Tab | Description |
|-----|-------------|
| **Borrowed Devices** | Track which electronics and MiFis are borrowed, by whom, and when |
| **Expenses** | Log and group expenses by month with yearly filter and EGP totals |
| **Bills** | Track recurring bills by category (MiFis, 4G Internet, Landline, Mobile Phone) |

### Settings & Export
- 🌙 **Dark mode** (on by default) with persistent preference
- 🏢 **Company name** shown in Inventory header
- 💾 **Backup** — save JSON to any location via file picker
- 📥 **Restore** — import from a backup JSON file
- 📊 **Export Devices** — export any device category to Excel (.xlsx)
- 📈 **Export Expenses** — export by custom date range to Excel
- 🏷️ **Label PDF** — generate 3-column device label sheets for printing
- ⚙️ **Onboarding** — company name setup on first launch

---

## Screenshots

> Add your screenshots here.

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.3.0`
- Android SDK 36 (compile), API 31 minimum
- NDK `28.2.13676358`
- Java 17

### Clone & Run
```bash
git clone https://github.com/your-username/inventorya.git
cd inventorya
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build AAB (for Play Store)
```bash
flutter build appbundle --release
```

---

## Project Structure

```
lib/
├── main.dart                  # App entry point, theme wiring, onboarding check
├── theme/
│   └── app_theme.dart         # Material You light & dark themes
├── models/                    # Pure data classes (no Flutter dependency)
│   ├── laptop.dart
│   ├── network_device.dart
│   ├── mifi.dart
│   ├── printer.dart
│   ├── electronic.dart
│   ├── employee.dart
│   ├── borrow_log.dart
│   ├── expense.dart
│   ├── bill.dart
│   └── email_account.dart
├── database/
│   └── database_helper.dart   # Singleton SQLite helper (sqflite), schema v5
├── services/
│   ├── theme_service.dart     # Dark/light mode, SharedPreferences, singleton
│   ├── company_service.dart   # Company name persistence, onboarding flag
│   ├── excel_service.dart     # Excel export via excel package + share_plus
│   └── label_service.dart     # PDF label generation via pdf package
├── widgets/
│   └── common_widgets.dart    # Shared: StatusBadge, IconBox, EmptyState,
│                              #         SearchBar2, DetailRow, SectionLabel,
│                              #         showConfirmDialog, showSnack
└── screens/
    ├── home_screen.dart        # Root: 6-tab NavigationBar
    ├── onboarding/            # First-launch company name screen
    ├── inventory/             # 5-tab TabBar host (Laptops→Electronics)
    ├── laptops/
    ├── network_devices/
    ├── mifis/
    ├── printers/
    ├── electronics/
    ├── employees/
    ├── borrowed/
    ├── expenses/
    ├── bills/
    ├── emails/
    └── settings/
```

---

## Database Schema

SQLite database (`inventorya.db`), **version 5**.

| Table | Key Columns |
|-------|-------------|
| `laptops` | laptop_number, model, cpu, gpu, ram, storage, condition, user, password |
| `network_devices` | device_number, model, phone_number, device_location, service_provider, wifi_name, wifi_password, gateway, admin_password, status |
| `mifis` | device_number, model, phone_number, wifi_name, wifi_password, quota, service_provider, gateway, admin_password, status |
| `printers` | printer_number, model, condition, location |
| `electronics` | device_number, device_name, details, status |
| `employees` | name, phone_number |
| `borrow_logs` | device_type, device_id, device_name, employee_name, reason, out_date, back_date, is_returned |
| `expenses` | date, item, price, details |
| `bills` | person, number, category, price, notes |
| `email_accounts` | employee_id, employee_name, email, password |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `sqflite` | Local SQLite database |
| `path_provider` | App directory paths |
| `path` | Path utilities |
| `intl` | Date & number formatting |
| `share_plus` | Share files via system sheet |
| `file_picker` | Open/save file dialogs |
| `pdf` | PDF label generation |
| `excel` | Excel (.xlsx) export |
| `shared_preferences` | Theme & company name persistence |

---

## Package Info

- **Package name:** `com.ma.inventorya`
- **Version:** `1.0.0+1`
- **Min SDK:** Android API 31 (Android 12)
- **Target SDK:** Android API 36

---

## License

MIT License — see [LICENSE](LICENSE) for details.
