/// The signed-in user, as returned by /auth/login and /auth/me.
class AppUser {

  // Server returns role as a nested object {"slug":..,"name":..}; older shape
  // used flat role_slug/role_name. Handle both.
  static String? _roleSlug(Map<String, dynamic> j) {
    final r = j['role'];
    if (r is Map) return r['slug'] as String?;
    return (j['role_slug'] ?? (r is String ? r : null)) as String?;
  }

  static String? _roleName(Map<String, dynamic> j) {
    final r = j['role'];
    if (r is Map) return r['name'] as String?;
    return j['role_name'] as String?;
  }

  final int id;
  final String? username;
  final String? email;
  final String firstName;
  final String lastName;
  final String? roleSlug;
  final String? roleName;
  final String? profilePhoto;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.username,
    this.email,
    this.roleSlug,
    this.roleName,
    this.profilePhoto,
  });

  String get fullName => [firstName, lastName]
      .where((s) => s.trim().isNotEmpty)
      .join(' ')
      .trim();

  String get initials {
    final a = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final b = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    final i = (a + b).toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  bool get isStudent => roleSlug == 'student';
  bool get isTeacher => roleSlug == 'teacher';
  bool get isAdminTier =>
      roleSlug == 'admin' || roleSlug == 'super_admin' || roleSlug == 'principal';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: j['username'] as String?,
        email: j['email'] as String?,
        firstName: (j['first_name'] as String?) ?? '',
        lastName: (j['last_name'] as String?) ?? '',
        roleSlug: _roleSlug(j),
        roleName: _roleName(j),
        profilePhoto: j['profile_photo'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role_slug': roleSlug,
        'role_name': roleName,
        'profile_photo': profilePhoto,
      };
}
