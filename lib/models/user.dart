class User {
  final int? id;
  final String email;
  final String password;
  final String name;
  final String about;

  User({
    this.id,
    required this.email,
    required this.password,
    required this.name,
    this.about = '',
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      name: map['name'] ?? '',
      about: map['about'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'name': name,
      'about': about,
    };
  }
}