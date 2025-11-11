class AppUser {
  final String id;
  final String username;
  final String name;
  final String? email;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
  });
}
