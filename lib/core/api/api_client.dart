import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../../features/profile/models/driver_details.dart';
import '../../features/profile/models/vehicle.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = supabase.Supabase.instance.client.auth.currentSession;

          if (AppConfig.hasSupabase) {
            if (session != null) {
              options.headers['Authorization'] =
                  'Bearer ${session.accessToken}';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  Dio get dio => _dio;

  Future<Map<String, dynamic>> syncProfile() async {
    final res = await _dio.post<Map<String, dynamic>>('/users/sync');
    return res.data!;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return res.data!;
  }

  Future<DriverDetails?> getDriverDetails() async {
    final res = await _dio.get<Map<String, dynamic>>('/driver-details');

    final data = res.data!['driverDetails'];

    if (data == null) {
      return null;
    }

    return DriverDetails.fromJson(data);
  }

  Future<List<dynamic>> searchGeocode(String query) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/geocode/search',
      queryParameters: {'q': query, 'limit': 6},
    );
    return (res.data!['results'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/geocode/reverse',
      queryParameters: {'lat': lat, 'lon': lon},
    );

    return res.data!;
  }

  Future<List<dynamic>> listCommutes({
    String? poolType,
    bool? womenOnly,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    DateTime? departureAt,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/commutes',
      queryParameters: {
        if (poolType != null) 'pool_type': poolType,

        if (womenOnly == true) 'women_only': 'true',

        if (fromLat != null) 'from_lat': fromLat,

        if (fromLng != null) 'from_lng': fromLng,

        if (toLat != null) 'to_lat': toLat,

        if (toLng != null) 'to_lng': toLng,

        if (departureAt != null)
          'departure_at': departureAt.toUtc().toIso8601String(),
      },
    );

    return (res.data!['commutes'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> myCreatedRides() async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/mine');

    return (res.data!['commutes'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> myBookedRides() async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/booked');

    return (res.data!['commutes'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> myRideHistory() async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/history');

    return (res.data!['commutes'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createCommute(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/commutes', data: body);
    return res.data!;
  }

  Future<Map<String, dynamic>> bookCommute(
    String commuteId, {
    int seats = 1,
    List<Map<String, String>> guests = const [],
    String travellingMode = 'me',
    String? travellingPassengerName,
    String? travellingPassengerGender,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/commutes/$commuteId/book',
      data: {
        'seats': seats,
        'guests': guests,
        'travelling_mode': travellingMode,
        if (travellingPassengerName != null &&
            travellingPassengerName.trim().isNotEmpty)
          'travelling_passenger_name': travellingPassengerName.trim(),
        if (travellingPassengerGender != null &&
            travellingPassengerGender.trim().isNotEmpty)
          'travelling_passenger_gender': travellingPassengerGender.trim(),
      },
    );
    return res.data!;
  }

  Future<void> cancelBooking(String commuteId, {String? reason}) async {
    await _dio.delete(
      '/commutes/$commuteId/book',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> setPaymentMethod({
    required String commuteId,
    required String bookingId,
    required String paymentMethod,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/commutes/$commuteId/bookings/$bookingId/payment-method',
      data: {'payment_method': paymentMethod},
    );
    print('>>> SET PAYMENT METHOD: $paymentMethod');
    print('>>> BOOKING: $bookingId');
    print('>>> RESPONSE: ${res.data}');
    return res.data!;
  }

  Future<Map<String, dynamic>> completeBookingPayment({
    required String commuteId,
    required String bookingId,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/commutes/$commuteId/bookings/$bookingId/payment-complete',
    );

    return res.data!;
  }

  Future<List<dynamic>> getRidePayments(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/commutes/$commuteId/payments',
    );
    print('>>> DRIVER PAYMENT POLL: ${res.data}');
    return (res.data!['payments'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createPaymentOrder(String bookingId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/payments/orders',
      data: {'booking_id': bookingId},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String bookingId,
    required String paymentId,
    String? orderId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/payments/confirm',
      data: {
        'booking_id': bookingId,
        'razorpay_payment_id': paymentId,
        if (orderId != null) 'razorpay_order_id': orderId,
      },
    );
    return res.data!;
  }

  Future<List<dynamic>> getChatMessages(
    String commuteId,
    String participantId,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/chat/$commuteId/$participantId',
    );

    return (res.data!['messages'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String commuteId,
    String participantId,
    String body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/chat/$commuteId/$participantId',
      data: {'body': body},
    );

    return res.data!;
  }

  Future<int> markChatMessagesRead(
    String commuteId,
    String participantId,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/chat/$commuteId/$participantId/read',
    );

    return (res.data!['marked_read'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> getUnreadChatMessages() async {
    final res = await _dio.get<Map<String, dynamic>>('/chat/unread');

    return res.data ?? {'total_unread': 0, 'conversations': <dynamic>[]};
  }

  Future<List<dynamic>> getPassengers(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/commutes/$commuteId/passengers',
    );

    return (res.data!['passengers'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> getCommute(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/$commuteId');

    return res.data!['commute'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActiveRide() async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/active');

    return res.data!;
  }

  Future<void> completeRide(String commuteId) async {
    await _dio.patch('/commutes/$commuteId/complete');
  }

  Future<void> startRide(String commuteId) async {
    await _dio.patch('/commutes/$commuteId/start');
  }

  Future<void> acceptBooking(String commuteId, String bookingId) async {
    await _dio.patch('/commutes/$commuteId/bookings/$bookingId/accept');
  }

  Future<void> rejectBooking(String commuteId, String bookingId) async {
    await _dio.patch('/commutes/$commuteId/bookings/$bookingId/reject');
  }

  Future<Map<String, dynamic>> verifyPassengerOtp({
    required String commuteId,
    required String bookingId,
    required String otp,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/commutes/$commuteId/bookings/$bookingId/verify-otp',
      data: {'otp': otp},
    );

    return res.data!;
  }

  Future<void> cancelRide(String commuteId, {String? reason}) async {
    await _dio.patch(
      '/commutes/$commuteId/cancel',
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> uploadStudentId({
    required XFile frontFile,
    required XFile backFile,
  }) async {
    final frontBytes = await frontFile.readAsBytes();
    final backBytes = await backFile.readAsBytes();

    final formData = FormData.fromMap({
      'frontIdCard': MultipartFile.fromBytes(
        frontBytes,
        filename: frontFile.name,
      ),
      'backIdCard': MultipartFile.fromBytes(backBytes, filename: backFile.name),
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '/verification/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> getVerificationStatus({
    required String type,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/verification/status',
      queryParameters: {'type': type},
    );

    return res.data!;
  }

  Future<String> uploadProfilePhoto(XFile image) async {
    final client = supabase.Supabase.instance.client;

    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final bytes = await image.readAsBytes();

    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const supabase.FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(path);

    return publicUrl;
  }

  Future<String> uploadDriverLicense(XFile image, String side) async {
    final client = supabase.Supabase.instance.client;

    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final bytes = await image.readAsBytes();

    final path = '${user.id}/$side.jpg';

    await client.storage
        .from('driver-licenses')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const supabase.FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return client.storage.from('driver-licenses').getPublicUrl(path);
  }

  Future<DriverDetails> saveDriverDetails({
    required String vehicleType,
    required String vehicleName,
    required String vehicleNumber,
    String? vehicleColor,
    required String licenseFrontUrl,
    required String licenseBackUrl,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/driver-details',
      data: {
        'vehicle_type': vehicleType,
        'vehicle_name': vehicleName,
        'vehicle_number': vehicleNumber,
        'vehicle_color': vehicleColor,
        'license_front_url': licenseFrontUrl,
        'license_back_url': licenseBackUrl,
      },
    );

    return DriverDetails.fromJson(res.data!['driverDetails']);
  }

  Future<List<dynamic>> getInterests() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/interests');
    return (res.data?['interests'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String institutionName,
    required String branch,
    required String rollNumber,
    required int admissionYear,
    required String gender,
    String? avatarUrl,
    List<int> interestIds = const [],
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'institution_name': institutionName,
        'branch': branch,
        'roll_number': rollNumber,
        'admission_year': admissionYear,
        'gender': gender,
        'interests': interestIds,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> getRatingEligible(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/commutes/$commuteId/rating-eligible',
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> getMyRatings() async {
    final res = await _dio.get<Map<String, dynamic>>('/commutes/ratings');

    return res.data!;
  }

  Future<Map<String, dynamic>> submitRating({
    required String commuteId,
    required String ratedId,
    required int score,
    String? comment,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/commutes/$commuteId/ratings',
      data: {
        'rated_id': ratedId,
        'score': score,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );

    return res.data!;
  }
  // ============================================================
  // EMERGENCY CONTACTS
  // ============================================================

  Future<List<dynamic>> getEmergencyContacts() async {
    final res = await _dio.get<Map<String, dynamic>>('/emergency-contacts');

    return (res.data?['contacts'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phoneNumber,
    String? relationship,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/emergency-contacts',
      data: {
        'name': name.trim(),
        'phone_number': phoneNumber.trim(),
        if (relationship != null && relationship.trim().isNotEmpty)
          'relationship': relationship.trim(),
      },
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> updateEmergencyContact({
    required String contactId,
    required String name,
    required String phoneNumber,
    String? relationship,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/emergency-contacts/$contactId',
      data: {
        'name': name.trim(),
        'phone_number': phoneNumber.trim(),
        if (relationship != null && relationship.trim().isNotEmpty)
          'relationship': relationship.trim(),
      },
    );

    return res.data!;
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _dio.delete('/emergency-contacts/$contactId');
  }
  // ============================================================
  // TRIP SAFETY
  // ============================================================

  Future<Map<String, dynamic>> getTripSafetySession(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>('/trip-safety/$commuteId');

    return res.data?['session'] as Map<String, dynamic>? ?? {};
  }

  Future<String> getTripSafetyShareLink(String commuteId) async {
    final session = await getTripSafetySession(commuteId);

    final shareToken = session['share_token']?.toString();

    if (shareToken == null || shareToken.isEmpty) {
      throw Exception('Trip safety share link is unavailable.');
    }

    return '${AppConfig.apiBaseUrl}/trip-safety/share/$shareToken';
  }

  Future<Map<String, dynamic>> getSharedTripSafety(String shareToken) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/trip-safety/share/$shareToken',
    );

    return res.data?['session'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateTripSafetyLocation({
    required String commuteId,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/trip-safety/$commuteId/location',
      data: {'latitude': latitude, 'longitude': longitude},
    );

    return res.data?['session'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> endTripSafetySession(String commuteId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/trip-safety/$commuteId/end',
    );

    return res.data?['session'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> triggerSosAlert({
    required String commuteId,
    String? message,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/trip-safety/$commuteId/sos',
      data: {
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );

    return res.data?['alert'] as Map<String, dynamic>? ?? {};
  }
  // ============================================================
  // CUSTOMER SUPPORT
  // ============================================================

  Future<Map<String, dynamic>> getSupportTickets() async {
    final res = await _dio.get<Map<String, dynamic>>('/support/tickets');
    return res.data!;
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String category,
    required String description,
    String? commuteId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/support/tickets',
      data: {
        'category': category,
        'description': description.trim(),
        if (commuteId != null && commuteId.trim().isNotEmpty)
          'commute_id': commuteId.trim(),
      },
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> getSupportTicket(String ticketId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/support/tickets/$ticketId',
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> replyToSupportTicket(
    String ticketId, {
    required String message,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/support/tickets/$ticketId/reply',
      data: {'message': message.trim()},
    );

    return res.data!;
  }

  Future<Map<String, dynamic>> getOperationsSupportTickets({
    String status = 'open',
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final res = await _dio.get(
      '/operations/support/tickets',
      queryParameters: {
        'status': status,
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> getOperationsSupportTicket(
    String ticketId,
  ) async {
    final res = await _dio.get('/operations/support/tickets/$ticketId');
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> replyToOperationsSupportTicket(
    String ticketId, {
    required String message,
  }) async {
    final res = await _dio.post(
      '/operations/support/tickets/$ticketId/reply',
      data: {'message': message},
    );
    return Map<String, dynamic>.from(res.data ?? {});
  }

  Future<Map<String, dynamic>> resolveOperationsSupportTicket(
    String ticketId,
  ) async {
    final res = await _dio.put('/operations/support/tickets/$ticketId/resolve');
    return Map<String, dynamic>.from(res.data ?? {});
  }
  // ============================================================
  // VEHICLES
  // ============================================================

  Future<List<Vehicle>> getVehicles() async {
    final res = await _dio.get<Map<String, dynamic>>('/vehicles');

    final vehicles = res.data?['vehicles'] as List<dynamic>? ?? [];

    return vehicles
        .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Vehicle> addVehicle({
    required String vehicleType,
    required String vehicleName,
    required String vehicleNumber,
    String? vehicleColor,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/vehicles',
      data: {
        'vehicle_type': vehicleType,
        'vehicle_name': vehicleName.trim(),
        'vehicle_number': vehicleNumber.trim(),
        'vehicle_color': vehicleColor?.trim(),
      },
    );

    return Vehicle.fromJson(Map<String, dynamic>.from(res.data!['vehicle']));
  }

  Future<Vehicle> updateVehicle({
    required String vehicleId,
    String? vehicleType,
    String? vehicleName,
    String? vehicleNumber,
    String? vehicleColor,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/vehicles/$vehicleId',
      data: {
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (vehicleName != null) 'vehicle_name': vehicleName.trim(),
        if (vehicleNumber != null) 'vehicle_number': vehicleNumber.trim(),
        if (vehicleColor != null) 'vehicle_color': vehicleColor.trim(),
      },
    );

    return Vehicle.fromJson(Map<String, dynamic>.from(res.data!['vehicle']));
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _dio.delete('/vehicles/$vehicleId');
  }
}
