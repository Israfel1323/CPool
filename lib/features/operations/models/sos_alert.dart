class SosAlert {
  final String id;
  final String tripSafetySessionId;
  final String commuteId;
  final String userId;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? message;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  final String? userName;
  final String? userDisplayName;
  final String? userEmail;
  final String? userPhone;

  final String? driverId;
  final String? fromAddress;
  final String? toAddress;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final DateTime? departureAt;
  final String? commuteStatus;

  final DateTime? sessionStartedAt;
  final DateTime? sessionEndedAt;
  final DateTime? sessionExpiresAt;
  final double? latestLatitude;
  final double? latestLongitude;
  final DateTime? lastLocationUpdateAt;

  const SosAlert({
    required this.id,
    required this.tripSafetySessionId,
    required this.commuteId,
    required this.userId,
    required this.status,
    this.latitude,
    this.longitude,
    this.message,
    this.createdAt,
    this.resolvedAt,
    this.userName,
    this.userDisplayName,
    this.userEmail,
    this.userPhone,
    this.driverId,
    this.fromAddress,
    this.toAddress,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.departureAt,
    this.commuteStatus,
    this.sessionStartedAt,
    this.sessionEndedAt,
    this.sessionExpiresAt,
    this.latestLatitude,
    this.latestLongitude,
    this.lastLocationUpdateAt,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    DateTime? toDateTime(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SosAlert(
      id: json['id']?.toString() ?? '',
      tripSafetySessionId:
          json['trip_safety_session_id']?.toString() ?? '',
      commuteId: json['commute_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      message: json['message']?.toString(),
      createdAt: toDateTime(json['created_at']),
      resolvedAt: toDateTime(json['resolved_at']),
      userName: json['user_name']?.toString(),
      userDisplayName: json['user_display_name']?.toString(),
      userEmail: json['user_email']?.toString(),
      userPhone: json['user_phone']?.toString(),
      driverId: json['driver_id']?.toString(),
      fromAddress: json['from_address']?.toString(),
      toAddress: json['to_address']?.toString(),
      fromLat: toDouble(json['from_lat']),
      fromLng: toDouble(json['from_lng']),
      toLat: toDouble(json['to_lat']),
      toLng: toDouble(json['to_lng']),
      departureAt: toDateTime(json['departure_at']),
      commuteStatus: json['commute_status']?.toString(),
      sessionStartedAt: toDateTime(json['started_at']),
      sessionEndedAt: toDateTime(json['ended_at']),
      sessionExpiresAt: toDateTime(json['expires_at']),
      latestLatitude: toDouble(json['latest_latitude']),
      latestLongitude: toDouble(json['latest_longitude']),
      lastLocationUpdateAt:
          toDateTime(json['last_location_update_at']),
    );
  }

  String get displayName {
    if (userName != null && userName!.trim().isNotEmpty) {
      return userName!.trim();
    }

    if (userDisplayName != null &&
        userDisplayName!.trim().isNotEmpty) {
      return userDisplayName!.trim();
    }

    return 'Unknown user';
  }

  bool get isActive => status == 'active';
}