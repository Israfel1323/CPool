class DriverDetails {
  final String userId;
  final String vehicleType;
  final String vehicleName;
  final String vehicleNumber;
  final String? vehicleColor;
  final String? licenseFrontUrl;
  final String? licenseBackUrl;
  final String verificationStatus;

  const DriverDetails({
    required this.userId,
    required this.vehicleType,
    required this.vehicleName,
    required this.vehicleNumber,
    this.vehicleColor,
    this.licenseFrontUrl,
    this.licenseBackUrl,
    required this.verificationStatus,
  });

  factory DriverDetails.fromJson(Map<String, dynamic> json) {
    return DriverDetails(
      userId: json['user_id'],
      vehicleType: json['vehicle_type'],
      vehicleName: json['vehicle_name'],
      vehicleNumber: json['vehicle_number'],
      vehicleColor: json['vehicle_color'],
      licenseFrontUrl: json['license_front_url'],
      licenseBackUrl: json['license_back_url'],
      verificationStatus: json['verification_status'],
    );
  }
}