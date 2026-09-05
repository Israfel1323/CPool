class DashboardStats {
  final int pendingVerifications;
  final int approvedVerifications;
  final int rejectedVerifications;
  final int pendingDrivers;
  final int pendingStudents;

  const DashboardStats({
    required this.pendingVerifications,
    required this.approvedVerifications,
    required this.rejectedVerifications,
    required this.pendingDrivers,
    required this.pendingStudents,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      pendingVerifications:
          int.tryParse(json['pending_verifications'].toString()) ?? 0,
      approvedVerifications:
          int.tryParse(json['approved_verifications'].toString()) ?? 0,
      rejectedVerifications:
          int.tryParse(json['rejected_verifications'].toString()) ?? 0,
      pendingDrivers:
          int.tryParse(json['pending_drivers'].toString()) ?? 0,
      pendingStudents:
          int.tryParse(json['pending_students'].toString()) ?? 0,
    );
  }
}