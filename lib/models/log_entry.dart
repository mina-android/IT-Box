class LogEntry {
  final int? id;
  final String date;          // yyyy-MM-dd
  final int? employeeId;
  final String employeeName;  // denormalized for fast display
  final String problem;
  final String solution;

  const LogEntry({
    this.id,
    required this.date,
    this.employeeId,
    this.employeeName = '',
    required this.problem,
    this.solution = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'problem': problem,
    'solution': solution,
  };

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
    id: m['id'] as int?,
    date: (m['date'] ?? '') as String,
    employeeId: m['employee_id'] as int?,
    employeeName: (m['employee_name'] ?? '') as String,
    problem: (m['problem'] ?? '') as String,
    solution: (m['solution'] ?? '') as String,
  );

  LogEntry copyWith({
    int? id, String? date, int? employeeId,
    String? employeeName, String? problem, String? solution,
  }) => LogEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    employeeId: employeeId ?? this.employeeId,
    employeeName: employeeName ?? this.employeeName,
    problem: problem ?? this.problem,
    solution: solution ?? this.solution,
  );
}
