import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

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
          print('========== API DEBUG ==========');
print('URL: ${options.path}');
print('hasSupabase: ${AppConfig.hasSupabase}');

final session =
    supabase.Supabase.instance.client.auth.currentSession;

print('Session exists: ${session != null}');
print('Access Token: ${session?.accessToken.substring(0, 20)}...');
          if (AppConfig.hasSupabase) {
            final session = supabase.Supabase.instance.client.auth.currentSession;
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

  Future<List<dynamic>> searchGeocode(String query) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/geocode/search',
      queryParameters: {'q': query, 'limit': 6},
    );
    return (res.data!['results'] as List<dynamic>?) ?? [];
  }

Future<List<dynamic>> listCommutes({
  String? poolType,
  bool? womenOnly,
  double? fromLat,
  double? fromLng,
  double? toLat,
  double? toLng,
}) async {
  final res = await _dio.get<Map<String, dynamic>>(
    '/commutes',
    queryParameters: {
      if (poolType != null)
        'pool_type': poolType,

      if (womenOnly == true)
        'women_only': 'true',

      if (fromLat != null)
        'from_lat': fromLat,

      if (fromLng != null)
        'from_lng': fromLng,

      if (toLat != null)
        'to_lat': toLat,

      if (toLng != null)
        'to_lng': toLng,
    },
  );

  return (res.data!['commutes'] as List<dynamic>?) ?? [];
}
Future<List<dynamic>> myCreatedRides() async {
  final res = await _dio.get<Map<String, dynamic>>(
    '/commutes/mine',
  );

  return (res.data!['commutes'] as List<dynamic>?) ?? [];
}
Future<List<dynamic>> myBookedRides() async {
  final res = await _dio.get<Map<String, dynamic>>(
    '/commutes/booked',
  );

  return (res.data!['commutes'] as List<dynamic>?) ?? [];
}
Future<List<dynamic>> myRideHistory() async {
  final res =
      await _dio.get<Map<String, dynamic>>(
    '/commutes/history',
  );

  return (res.data!['commutes']
          as List<dynamic>?) ??
      [];
}

  Future<Map<String, dynamic>> createCommute(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/commutes', data: body);
    return res.data!;
  }

  Future<Map<String, dynamic>> bookCommute(String commuteId, {int seats = 1}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/commutes/$commuteId/book',
      data: {'seats': seats},
    );
    return res.data!;
  }
  Future<void> cancelBooking(
  String commuteId,
) async {
  await _dio.delete(
    '/commutes/$commuteId/book',
  );
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
  if (orderId != null)
    'razorpay_order_id': orderId,
},
    );
    return res.data!;
  }

  Future<List<dynamic>> getChatMessages(String commuteId) async {
    final res = await _dio.get<Map<String, dynamic>>('/chat/$commuteId');
    return (res.data!['messages'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String commuteId,
    String body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/chat/$commuteId',
      data: {'body': body},
    );
    return res.data!;
  }
  Future<List<dynamic>> getPassengers(
  String commuteId,
) async {
  final res =
      await _dio.get<Map<String, dynamic>>(
    '/commutes/$commuteId/passengers',
  );

  return (res.data!['passengers']
          as List<dynamic>?) ??
      [];
}
Future<void> completeRide(
  String commuteId,
) async {
  await _dio.patch(
    '/commutes/$commuteId/complete',
  );
}

Future<void> cancelRide(
  String commuteId,
) async {
  await _dio.patch(
    '/commutes/$commuteId/cancel',
  );
}
Future<Map<String, dynamic>> uploadStudentId(
  XFile file,
) async {
  final bytes = await file.readAsBytes();

  final formData = FormData.fromMap({
    'idCard': MultipartFile.fromBytes(
      bytes,
      filename: file.name,
    ),
  });

  final res = await _dio.post<Map<String, dynamic>>(
    '/verification/upload',
    data: formData,
    options: Options(
      contentType: 'multipart/form-data',
    ),
  );

  return res.data!;
}
Future<Map<String, dynamic>> getVerificationStatus() async {
  final res = await _dio.get<Map<String, dynamic>>(
    '/verification/status',
  );

  return res.data!;
}
Future<Map<String, dynamic>> updateProfile({
  required String fullName,
  required String phoneNumber,
  required String branch,
  required String rollNumber,
  required int admissionYear,
}) async {
  final res = await _dio.patch<Map<String, dynamic>>(
    '/users/me',
    data: {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'branch': branch,
      'roll_number': rollNumber,
      'admission_year': admissionYear,
    },
  );

  return res.data!;
}
}
