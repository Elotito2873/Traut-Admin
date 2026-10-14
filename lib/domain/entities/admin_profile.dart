class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.avatarPreset,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? avatarPreset;

  bool get isAdmin => role == 'admin';
}
