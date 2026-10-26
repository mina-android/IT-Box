// lib/database/tables.dart
import 'package:drift/drift.dart';

@DataClassName('LaptopEntry')
class Laptops extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get laptopNumber => text().named('laptop_number')();
  TextColumn get model => text().named('model')();
  TextColumn get cpu => text().named('cpu').withDefault(const Constant(''))();
  TextColumn get gpu => text().named('gpu').withDefault(const Constant(''))();
  TextColumn get ram => text().named('ram').withDefault(const Constant(''))();
  TextColumn get storage => text().named('storage').withDefault(const Constant(''))();
  TextColumn get condition => text().named('condition').withDefault(const Constant('Good'))();
  TextColumn get user => text().named('user').withDefault(const Constant(''))();
  TextColumn get password => text().named('password').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
  TextColumn get createdAt => text().named('created_at').nullable()();
}

@DataClassName('NetworkDeviceEntry')
class NetworkDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceNumber => text().named('device_number')();
  TextColumn get model => text().named('model')();
  TextColumn get phoneNumber => text().named('phone_number').withDefault(const Constant(''))();
  TextColumn get deviceLocation => text().named('device_location').withDefault(const Constant(''))();
  TextColumn get serviceProvider => text().named('service_provider').withDefault(const Constant(''))();
  TextColumn get wifiName => text().named('wifi_name').withDefault(const Constant(''))();
  TextColumn get wifiPassword => text().named('wifi_password').withDefault(const Constant(''))();
  TextColumn get gateway => text().named('gateway').withDefault(const Constant(''))();
  TextColumn get adminPassword => text().named('admin_password').withDefault(const Constant(''))();
  TextColumn get status => text().named('status').withDefault(const Constant('Available'))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('PrinterEntry')
class Printers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get printerNumber => text().named('printer_number')();
  TextColumn get model => text().named('model')();
  TextColumn get condition => text().named('condition').withDefault(const Constant('Good'))();
  TextColumn get location => text().named('location').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('ElectronicEntry')
class Electronics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceNumber => text().named('device_number')();
  TextColumn get deviceName => text().named('device_name')();
  TextColumn get details => text().named('details').withDefault(const Constant(''))();
  TextColumn get status => text().named('status').withDefault(const Constant('Available'))();
  IntColumn get excludeBorrowing => integer().named('exclude_borrowing').withDefault(const Constant(0))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('EmployeeEntry')
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().named('name')();
  TextColumn get phoneNumber => text().named('phone_number').withDefault(const Constant(''))();
}

@DataClassName('BorrowLogEntry')
class BorrowLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceType => text().named('device_type')();
  IntColumn get deviceId => integer().named('device_id')();
  TextColumn get deviceName => text().named('device_name')();
  TextColumn get deviceNumber => text().named('device_number')();
  IntColumn get employeeId => integer().named('employee_id')();
  TextColumn get employeeName => text().named('employee_name')();
  TextColumn get reason => text().named('reason').withDefault(const Constant(''))();
  TextColumn get outDate => text().named('out_date')();
  TextColumn get backDate => text().named('back_date').nullable()();
  TextColumn get dueDate => text().named('due_date').nullable()();
  TextColumn get reminderTime => text().named('reminder_time').nullable()();
  IntColumn get isReturned => integer().named('is_returned').withDefault(const Constant(0))();
}

@DataClassName('MiFiEntry')
class Mifis extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceNumber => text().named('device_number')();
  TextColumn get model => text().named('model')();
  TextColumn get phoneNumber => text().named('phone_number').withDefault(const Constant(''))();
  TextColumn get wifiName => text().named('wifi_name').withDefault(const Constant(''))();
  TextColumn get wifiPassword => text().named('wifi_password').withDefault(const Constant(''))();
  TextColumn get quota => text().named('quota').withDefault(const Constant(''))();
  TextColumn get serviceProvider => text().named('service_provider').withDefault(const Constant(''))();
  TextColumn get gateway => text().named('gateway').withDefault(const Constant(''))();
  TextColumn get adminPassword => text().named('admin_password').withDefault(const Constant(''))();
  TextColumn get status => text().named('status').withDefault(const Constant('Available'))();
  IntColumn get excludeBorrowing => integer().named('exclude_borrowing').withDefault(const Constant(0))();
  TextColumn get tag => text().named('tag').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('ExpenseEntry')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().named('date')();
  TextColumn get item => text().named('item')();
  RealColumn get price => real().named('price').withDefault(const Constant(0.0))();
  TextColumn get details => text().named('details').withDefault(const Constant(''))();
}

@DataClassName('BillEntry')
class Bills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text().named('person').withDefault(const Constant(''))();
  TextColumn get number => text().named('number')();
  TextColumn get category => text().named('category')();
  RealColumn get price => real().named('price').withDefault(const Constant(0.0))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('EmailAccountEntry')
class EmailAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().named('employee_id').nullable()();
  TextColumn get employeeName => text().named('employee_name').withDefault(const Constant(''))();
  TextColumn get email => text().named('email')();
  TextColumn get password => text().named('password')();
}

@DataClassName('LogEntryTableEntry')
class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().named('date')();
  IntColumn get employeeId => integer().named('employee_id').nullable()();
  TextColumn get employeeName => text().named('employee_name').withDefault(const Constant(''))();
  TextColumn get problem => text().named('problem')();
  TextColumn get solution => text().named('solution').withDefault(const Constant(''))();
  TextColumn get state => text().named('state').withDefault(const Constant('Open'))();
  TextColumn get priority => text().named('priority').withDefault(const Constant('Low'))();
}

@DataClassName('SubscriptionEntry')
class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get service => text().named('service')();
  TextColumn get type => text().named('type')();
  RealColumn get price => real().named('price').withDefault(const Constant(0.0))();
  TextColumn get renewalDate => text().named('renewal_date').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('AccessPointEntry')
class AccessPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceNumber => text().named('device_number')();
  TextColumn get model => text().named('model')();
  TextColumn get portNumber => text().named('port_number').withDefault(const Constant(''))();
  TextColumn get location => text().named('location').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('MaintenanceEntry')
class DeviceMaintenanceLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceType => text().named('device_type')(); // 'laptop', 'network', 'printer', 'electronic', 'mifi'
  IntColumn get deviceId => integer().named('device_id')();
  TextColumn get date => text().named('date')(); // YYYY-MM-DD
  TextColumn get serviceType => text().named('service_type').withDefault(const Constant('Maintenance'))();
  RealColumn get cost => real().named('cost').withDefault(const Constant(0.0))();
  TextColumn get details => text().named('details').withDefault(const Constant(''))();
  TextColumn get performedBy => text().named('performed_by').withDefault(const Constant(''))();
  IntColumn get isPlanned => integer().named('is_planned').withDefault(const Constant(0))();
  TextColumn get plannedDate => text().named('planned_date').withDefault(const Constant(''))();
}

@DataClassName('StaticIpEntry')
class StaticIps extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ipAddress => text().named('ip_address')();
  TextColumn get subnetMask => text().named('subnet_mask').withDefault(const Constant('255.255.255.0'))();
  TextColumn get assignedDevice => text().named('assigned_device')();
  TextColumn get deviceType => text().named('device_type').withDefault(const Constant('Other'))();
  TextColumn get macAddress => text().named('mac_address').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
}

@DataClassName('SwitchPatchPortEntry')
class SwitchPatchPorts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get switchDeviceId => integer().named('switch_device_id')();
  IntColumn get portNumber => integer().named('port_number')();
  TextColumn get connectedDevice => text().named('connected_device').withDefault(const Constant(''))();
  TextColumn get destinationRoom => text().named('destination_room').withDefault(const Constant(''))();
  TextColumn get vlan => text().named('vlan').withDefault(const Constant('1'))();
  TextColumn get status => text().named('status').withDefault(const Constant('Active'))();
}

@DataClassName('AuditActivityEntry')
class AuditActivities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionType => text().named('action_type')(); // 'CREATE', 'UPDATE', 'DELETE', 'CHECKOUT', 'CHECKIN'
  TextColumn get entityType => text().named('entity_type')(); // 'Laptop', 'Borrow', etc.
  IntColumn get entityId => integer().named('entity_id').nullable()();
  TextColumn get description => text().named('description')();
  TextColumn get timestamp => text().named('timestamp')(); // ISO-8601
}

@DataClassName('WifiNetworkEntry')
class WifiNetworks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get networkName => text().named('network_name')();
  TextColumn get password => text().named('password').withDefault(const Constant(''))();
  TextColumn get phoneNumber => text().named('phone_number').withDefault(const Constant(''))();
  TextColumn get locationDevice => text().named('location_device').withDefault(const Constant(''))();
  TextColumn get adminUsername => text().named('admin_username').withDefault(const Constant(''))();
  TextColumn get adminPassword => text().named('admin_password').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
  TextColumn get createdAt => text().named('created_at').nullable()();
}

@DataClassName('AccountPasswordEntry')
class AccountPasswords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text().named('platform')();
  TextColumn get emailUsername => text().named('email_username')();
  TextColumn get password => text().named('password')();
  TextColumn get createdAt => text().named('created_at').nullable()();
}

@DataClassName('OtherDeviceEntry')
class OtherDevices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceType => text().named('device_type')();
  TextColumn get deviceName => text().named('device_name')();
  TextColumn get model => text().named('model').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
  TextColumn get createdAt => text().named('created_at').nullable()();
}

@DataClassName('VendorContactEntry')
class VendorContacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contactType => text().named('contact_type')(); // 'ISP', 'Vendor', 'Domain/Registrar', 'Cloud/SaaS', 'Internal'
  TextColumn get name => text().named('name')();
  TextColumn get company => text().named('company').withDefault(const Constant(''))();
  TextColumn get role => text().named('role').withDefault(const Constant(''))();
  TextColumn get phoneNumber => text().named('phone_number').withDefault(const Constant(''))();
  TextColumn get email => text().named('email').withDefault(const Constant(''))();
  TextColumn get portalUrl => text().named('portal_url').withDefault(const Constant(''))();
  TextColumn get accountNumber => text().named('account_number').withDefault(const Constant(''))();
  TextColumn get notes => text().named('notes').withDefault(const Constant(''))();
  TextColumn get createdAt => text().named('created_at').nullable()();
}
