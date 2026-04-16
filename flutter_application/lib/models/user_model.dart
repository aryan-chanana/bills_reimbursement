class User {
  final int employeeId;
  final String name;
  final String email;
  final String password;
  final bool isAdmin;
  final bool isApproved;

  User({
    required this.employeeId,
    required this.name,
    this.email = '',
    required this.password,
    this.isAdmin = false,
    this.isApproved = false
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      employeeId: json['employeeId'],
      name: json['name'],
      email: json['email'],
      password: json['password'] ?? '',
      isAdmin: json['admin'] ?? false,
      isApproved: json['approved'] ?? false,
    );
  }
}