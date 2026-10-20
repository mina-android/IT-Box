class LogEntry {
  final int? id;
  final String date;          // yyyy-MM-dd
  final int? employeeId;
  final String employeeName;  // denormalized for fast display
  final String problem;
  final String solution;
  final String state;
  final String priority;

  const LogEntry({
    this.id,
    required this.date,
    this.employeeId,
    this.employeeName = '',
    required this.problem,
    this.solution = '',
    this.state = 'Open',
    this.priority = 'Low',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'problem': problem,
    'solution': solution,
    'state': state,
    'priority': priority,
  };

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
    id: m['id'] as int?,
    date: (m['date'] ?? '') as String,
    employeeId: m['employee_id'] as int?,
    employeeName: (m['employee_name'] ?? '') as String,
    problem: (m['problem'] ?? '') as String,
    solution: (m['solution'] ?? '') as String,
    state: (m['state'] ?? 'Open') as String,
    priority: (m['priority'] ?? 'Low') as String,
  );

  LogEntry copyWith({
    int? id, String? date, int? employeeId,
    String? employeeName, String? problem, String? solution, String? state, String? priority,
  }) => LogEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    employeeId: employeeId ?? this.employeeId,
    employeeName: employeeName ?? this.employeeName,
    problem: problem ?? this.problem,
    solution: solution ?? this.solution,
    state: state ?? this.state,
    priority: priority ?? this.priority,
  );
}
