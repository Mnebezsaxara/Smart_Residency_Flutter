import 'api_client.dart';

class StaffMember {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String specialty;
  final String workSchedule;
  final String description;
  final bool isAvailable;

  const StaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialty,
    required this.workSchedule,
    required this.description,
    required this.isAvailable,
  });

  factory StaffMember.fromMap(Map<String, dynamic> m) => StaffMember(
        id: (m['id'] ?? '').toString(),
        fullName: (m['full_name'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        specialty: (m['specialty'] ?? '').toString(),
        workSchedule: (m['work_schedule'] ?? '').toString(),
        description: (m['description'] ?? '').toString(),
        isAvailable: m['is_available'] is bool
            ? m['is_available'] as bool
            : (m['is_available']?.toString() == 'true'),
      );
}

class StaffService {
  StaffService._();
  static final StaffService instance = StaffService._();

  final ApiClient _api = ApiClient.instance;

  /// Загружает публичный список сотрудников. Для резидента и админа.
  Future<List<StaffMember>> getStaff() async {
    final res = await _api.get('/staff');
    final list = (res.data as List)
        .map((m) => StaffMember.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    return list;
  }
}
