import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../models/dashboard_stats.dart';
import '../models/verification_request.dart';

class OperationsService {
  OperationsService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<DashboardStats> getDashboardStats() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/operations/dashboard',
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Dashboard response is empty.');
    }

    final data = json['data'] as Map<String, dynamic>;

    return DashboardStats.fromJson(data);
  }

  // ============================================================
  // VERIFICATION REQUESTS — LIST
  // ============================================================

  Future<List<VerificationRequest>> getVerificationRequests({
    int page = 1,
    int limit = 20,
    String status = 'pending',
    String? type,
    String search = '',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/operations/verification/requests',
      queryParameters: {
        'page': page,
        'limit': limit,
        'status': status,
        if (type != null) 'type': type,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Verification requests response is empty.');
    }

    final data = json['data'] as Map<String, dynamic>;

    final items = data['items'] as List<dynamic>? ?? [];

    return items
        .map(
          (item) => VerificationRequest.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  // ============================================================
  // VERIFICATION REQUEST — DETAILS
  // ============================================================

  Future<VerificationRequest> getVerificationRequest(
    String verificationId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/operations/verification/$verificationId',
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Verification request response is empty.');
    }

    return VerificationRequest.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<String> getVerificationDocumentUrl({
    required String verificationId,
    required String side,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/operations/verification/$verificationId/document/$side',
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Document URL response is empty.');
    }

    final data = json['data'] as Map<String, dynamic>;
    final url = data['url']?.toString();

    if (url == null || url.isEmpty) {
      throw Exception('Document URL was not returned.');
    }

    return url;
  }
  // ============================================================
  // APPROVE VERIFICATION
  // ============================================================

  Future<VerificationRequest> approveVerification(String verificationId) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/operations/verification/$verificationId/approve',
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Approval response is empty.');
    }

    return VerificationRequest.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ============================================================
  // REJECT VERIFICATION
  // ============================================================

  Future<VerificationRequest> rejectVerification(
    String verificationId,
    String reason,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/operations/verification/$verificationId/reject',
      data: {'reason': reason},
    );

    final json = response.data;

    if (json == null || json['data'] == null) {
      throw Exception('Rejection response is empty.');
    }

    return VerificationRequest.fromJson(json['data'] as Map<String, dynamic>);
  }
}
