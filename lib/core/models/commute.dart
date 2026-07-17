class Commute {
  const Commute({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    required this.departureAt,
    required this.poolType,
    required this.seatsAvailable,
    required this.costPerSeatPaise,
    this.driverName,
    this.womenOnly = false,
this.alreadyBooked = false,
  });

  final String id;
  final String fromAddress;
  final String toAddress;
  final DateTime departureAt;
  final String poolType;
  final int seatsAvailable;
  final int costPerSeatPaise;
  final String? driverName;
  final bool womenOnly;
  final bool alreadyBooked;

  factory Commute.fromJson(Map<String, dynamic> json) {
    return Commute(
      id: json['id'] as String,
      fromAddress: json['from_address'] as String? ?? '',
      toAddress: json['to_address'] as String? ?? '',
      departureAt: DateTime.parse(json['departure_at'] as String),
      poolType: json['pool_type'] as String? ?? 'carpool',
      seatsAvailable: json['seats_available'] as int? ?? 0,
      costPerSeatPaise: json['cost_per_seat_paise'] as int? ?? 0,
      driverName: json['driver_name'] as String?,
      womenOnly: json['women_only'] as bool? ?? false,
      alreadyBooked:
    json['already_booked'] as bool? ?? false,
    );
  }

  String get costDisplay {
    if (costPerSeatPaise <= 0) return 'Free';
    return '₹${(costPerSeatPaise / 100).toStringAsFixed(0)}/seat';
  }
}
