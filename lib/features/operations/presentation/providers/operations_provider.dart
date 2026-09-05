import 'package:flutter/material.dart';

import '../../models/dashboard_stats.dart';
import '../../models/verification_request.dart';
import '../../services/operations_service.dart';

class OperationsProvider extends ChangeNotifier {
  OperationsProvider({OperationsService? service})
    : _service = service ?? OperationsService();

  final OperationsService _service;

  DashboardStats? _stats;

  DashboardStats? get stats => _stats;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? _error;

  String? get error => _error;

  final List<VerificationRequest> _allVerificationRequests = [];
  final List<VerificationRequest> _verificationRequests = [];

  List<VerificationRequest> get verificationRequests =>
      List.unmodifiable(_verificationRequests);

  bool _isLoadingRequests = false;

  bool get isLoadingRequests => _isLoadingRequests;

  String? _requestsError;

  String? get requestsError => _requestsError;

  String _search = '';

  String get search => _search;

  VerificationRequest? _selectedRequest;

  VerificationRequest? get selectedRequest => _selectedRequest;

  bool _isLoadingDetails = false;

  bool get isLoadingDetails => _isLoadingDetails;

  bool _isUpdatingVerification = false;

  bool get isUpdatingVerification => _isUpdatingVerification;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      _stats = await _service.getDashboardStats();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;

    notifyListeners();
  }

  Future<void> loadVerificationRequests({String? type, String? search}) async {
    _isLoadingRequests = true;
    _requestsError = null;

    if (search != null) {
      _search = search;
    }

    notifyListeners();

    try {
      final data = await _service.getVerificationRequests(type: type);

      _allVerificationRequests
        ..clear()
        ..addAll(data);

      _applySearch();
    } catch (e) {
      _requestsError = e.toString();
    }

    _isLoadingRequests = false;

    notifyListeners();
  }

  void _applySearch() {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      _verificationRequests
        ..clear()
        ..addAll(_allVerificationRequests);
      return;
    }

    _verificationRequests
      ..clear()
      ..addAll(
        _allVerificationRequests.where((request) {
          final name = request.fullName?.toLowerCase() ?? '';
          final email = request.email?.toLowerCase() ?? '';

          return name.contains(query) || email.contains(query);
        }),
      );
  }

  void setVerificationSearch(String value) {
    _search = value;
    _applySearch();
    notifyListeners();
  }

  Future<void> loadVerificationRequest(String verificationId) async {
    _isLoadingDetails = true;
    _requestsError = null;

    notifyListeners();

    try {
      _selectedRequest = await _service.getVerificationRequest(verificationId);
    } catch (e) {
      _requestsError = e.toString();
    }

    _isLoadingDetails = false;

    notifyListeners();
  }

  Future<String> getVerificationDocumentUrl({
    required String verificationId,
    required String side,
  }) async {
    return _service.getVerificationDocumentUrl(
      verificationId: verificationId,
      side: side,
    );
  }

  Future<void> approveVerification(String verificationId) async {
    _isUpdatingVerification = true;
    _requestsError = null;

    notifyListeners();

    try {
      await _service.approveVerification(verificationId);

      // Re-fetch the complete request so profile,
      // vehicle and license information are preserved.
      _selectedRequest = await _service.getVerificationRequest(verificationId);

      _replaceRequest(_selectedRequest!);

      // Refresh dashboard counts.
      await loadDashboard();
    } catch (e) {
      _requestsError = e.toString();
      rethrow;
    } finally {
      _isUpdatingVerification = false;
      notifyListeners();
    }
  }

  Future<void> rejectVerification(String verificationId, String reason) async {
    _isUpdatingVerification = true;
    _requestsError = null;

    notifyListeners();

    try {
      await _service.rejectVerification(verificationId, reason);

      // Re-fetch the complete request so all details remain available.
      _selectedRequest = await _service.getVerificationRequest(verificationId);

      _replaceRequest(_selectedRequest!);

      // Refresh dashboard counts.
      await loadDashboard();
    } catch (e) {
      _requestsError = e.toString();
      rethrow;
    } finally {
      _isUpdatingVerification = false;
      notifyListeners();
    }
  }

  void _replaceRequest(VerificationRequest request) {
    final index = _verificationRequests.indexWhere(
      (item) => item.id == request.id,
    );

    if (index != -1) {
      _verificationRequests[index] = request;
    }
  }

  void clearSelectedRequest() {
    _selectedRequest = null;
    _requestsError = null;
    notifyListeners();
  }
}
