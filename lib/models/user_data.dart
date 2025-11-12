class UserData {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserData.fromJson(Map<String, dynamic> data) {
    return UserData(
      id: data['id'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      createdAt: DateTime.parse(data['created_at']),
    );
  }
}
