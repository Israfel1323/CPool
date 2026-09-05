import '../api/api_client.dart';
import '../../features/profile/models/driver_details.dart';

enum DriverVerificationStatus {
  notApplied,
  pending,
  approved,
  rejected,
}

enum StudentVerificationStatus {
  notApplied,
  pending,
  approved,
  rejected,
}

class VerificationService {
  VerificationService({ApiClient? api})
      : _api = api ?? ApiClient();

  final ApiClient _api;

  // ─────────────────────────────────────────────
  // DRIVER VERIFICATION
  // ─────────────────────────────────────────────

  Future<DriverVerificationStatus> driverStatus() async {
    final DriverDetails? details =
        await _api.getDriverDetails();

    if (details == null) {
      return DriverVerificationStatus.notApplied;
    }

    switch (details.verificationStatus) {
      case 'approved':
        return DriverVerificationStatus.approved;

      case 'pending':
        return DriverVerificationStatus.pending;

      case 'rejected':
        return DriverVerificationStatus.rejected;

      default:
        return DriverVerificationStatus.notApplied;
    }
  }

  Future<bool> canOfferRide() async {
    return (await driverStatus()) ==
        DriverVerificationStatus.approved;
  }

  // ─────────────────────────────────────────────
  // STUDENT VERIFICATION
  // ─────────────────────────────────────────────

  Future<StudentVerificationStatus> studentStatus() async {
    final data = await _api.getVerificationStatus(
      type: 'student',
    );

    final status =
        data['data']?['status']?.toString().toLowerCase() ??
        data['status']?.toString().toLowerCase();

    switch (status) {
      case 'approved':
        return StudentVerificationStatus.approved;

      case 'pending':
        return StudentVerificationStatus.pending;

      case 'rejected':
        return StudentVerificationStatus.rejected;

      default:
        return StudentVerificationStatus.notApplied;
    }
  }

  Future<bool> canFindRide() async {
    return (await studentStatus()) ==
        StudentVerificationStatus.approved;
  }
}