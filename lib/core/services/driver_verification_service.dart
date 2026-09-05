import '../api/api_client.dart';
import '../../features/profile/models/driver_details.dart';

enum DriverVerificationState { notApplied, pending, verified, rejected }

class DriverVerificationService {
  final ApiClient _api = ApiClient();

  Future<DriverVerificationState> getStatus() async {
    try {
      final DriverDetails? driver = await _api.getDriverDetails();

      if (driver == null) {
        return DriverVerificationState.notApplied;
      }

      switch (driver.verificationStatus) {
        case 'pending':
          return DriverVerificationState.pending;

        case 'approved':
          return DriverVerificationState.verified;

        case 'rejected':
          return DriverVerificationState.rejected;

        default:
          return DriverVerificationState.notApplied;
      }
    } catch (_) {
      return DriverVerificationState.notApplied;
    }
  }
}
