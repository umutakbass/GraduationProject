class AppUser {
  final int? id;
  final String name;
  final String email;
  final String password;

  AppUser({this.id, required this.name, required this.email, required this.password});

  factory AppUser.fromMap(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        password: json['password'],
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
    };
  }
}