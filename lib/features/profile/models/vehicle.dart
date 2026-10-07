class Vehicle {
  final String id;
  final String userId;
  final String vehicleType;
  final String vehicleName;
  final String vehicleNumber;
  final String? vehicleColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.vehicleName,
    required this.vehicleNumber,
    this.vehicleColor,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? '',
      vehicleName: json['vehicle_name']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      vehicleColor: json['vehicle_color']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}