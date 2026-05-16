class EmailAccount {
  final int? id;
  final int? employeeId;
  final String employeeName; // may be empty if no employee linked
  final String email;
  final String password;

  const EmailAccount({
    this.id,
    this.employeeId,
    this.employeeName = '',
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'email': email,
    'password': password,
  };

  factory EmailAccount.fromMap(Map<String, dynamic> m) => EmailAccount(
    id: m['id'] as int?,
    employeeId: m['employee_id'] as int?,
    employeeName: (m['employee_name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    password: (m['password'] ?? '') as String,
  );

  EmailAccount copyWith({int? id, int? employeeId, String? employeeName,
      String? email, String? password}) => EmailAccount(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    employeeName: employeeName ?? this.employeeName,
    email: email ?? this.email,
    password: password ?? this.password,
  );
}
