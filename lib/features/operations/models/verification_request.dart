class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.profileId,
    required this.verificationType,
    required this.status,
    required this.createdAt,
    this.institutionName,
    this.idCardUrl,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.referenceId,
    this.updatedAt,
    this.fullName,
    this.email,
    this.vehicleType,
    this.vehicleName,
    this.vehicleNumber,
    this.vehicleColor,
    this.licenseFrontUrl,
    this.licenseBackUrl,
  });

  final String id;
  final String profileId;

  final String verificationType;
  final String status;

  final DateTime createdAt;

  final String? institutionName;
  final String? idCardUrl;
  final String? idCardFrontUrl;
  final String? idCardBackUrl;

  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  final String? referenceId;
  final DateTime? updatedAt;

  // Profile information
  final String? fullName;
  final String? email;

  // Driver information
  final String? vehicleType;
  final String? vehicleName;
  final String? vehicleNumber;
  final String? vehicleColor;
  final String? licenseFrontUrl;
  final String? licenseBackUrl;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) {
    return VerificationRequest(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      verificationType: json['verification_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),

      institutionName: json['institution_name']?.toString(),

      idCardUrl: json['id_card_url']?.toString(),

      idCardFrontUrl: json['id_card_front_url']?.toString(),

      idCardBackUrl: json['id_card_back_url']?.toString(),

      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),

      referenceId: json['reference_id']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,

      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),

      vehicleType: json['vehicle_type']?.toString(),
      vehicleName: json['vehicle_name']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
      vehicleColor: json['vehicle_color']?.toString(),
      licenseFrontUrl: json['license_front_url']?.toString(),
      licenseBackUrl: json['license_back_url']?.toString(),
    );
  }
}
