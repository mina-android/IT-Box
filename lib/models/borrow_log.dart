class BorrowLog {
  final int? id;
  final String deviceType; // 'network' | 'electronic'
  final int deviceId;
  final String deviceName;
  final String deviceNumber;
  final int employeeId;
  final String employeeName;
  final String reason;
  final String outDate;
  final String? backDate;
  final bool isReturned;

  const BorrowLog({
    this.id,
    required this.deviceType,
    required this.deviceId,
    required this.deviceName,
    required this.deviceNumber,
    required this.employeeId,
    required this.employeeName,
    required this.reason,
    required this.outDate,
    this.backDate,
    this.isReturned = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'device_type': deviceType,
    'device_id': deviceId,
    'device_name': deviceName,
    'device_number': deviceNumber,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'reason': reason,
    'out_date': outDate,
    'back_date': backDate,
    'is_returned': isReturned ? 1 : 0,
  };

  factory BorrowLog.fromMap(Map<String, dynamic> m) => BorrowLog(
    id: m['id'] as int?,
    deviceType: (m['device_type'] ?? '') as String,
    deviceId: (m['device_id'] ?? 0) as int,
    deviceName: (m['device_name'] ?? '') as String,
    deviceNumber: (m['device_number'] ?? '') as String,
    employeeId: (m['employee_id'] ?? 0) as int,
    employeeName: (m['employee_name'] ?? '') as String,
    reason: (m['reason'] ?? '') as String,
    outDate: (m['out_date'] ?? '') as String,
    backDate: m['back_date'] as String?,
    isReturned: (m['is_returned'] as int? ?? 0) == 1,
  );

  BorrowLog copyWith({
    int? id, String? deviceType, int? deviceId, String? deviceName, String? deviceNumber,
    int? employeeId, String? employeeName, String? reason, String? outDate,
    String? backDate, bool? isReturned,
  }) => BorrowLog(
    id: id ?? this.id,
    deviceType: deviceType ?? this.deviceType,
    deviceId: deviceId ?? this.deviceId,
    deviceName: deviceName ?? this.deviceName,
    deviceNumber: deviceNumber ?? this.deviceNumber,
    employeeId: employeeId ?? this.employeeId,
    employeeName: employeeName ?? this.employeeName,
    reason: reason ?? this.reason,
    outDate: outDate ?? this.outDate,
    backDate: backDate ?? this.backDate,
    isReturned: isReturned ?? this.isReturned,
  );
}
