class Commute {
  const Commute({
    required this.id,
    required this.fromAddress,
    required this.toAddress,
    required this.departureAt,
    required this.poolType,
    required this.seatsAvailable,
    required this.costPerSeatPaise,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.seatsTotal,
    this.status,
    this.driverName,
    this.driverRating,
    this.driverRatingCount = 0,
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

  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  final int? seatsTotal;
  final String? status;

  final String? driverName;

  // Driver reputation.
  // Null rating means the driver has never received a rating.
  final double? driverRating;
  final int driverRatingCount;

  final bool womenOnly;
  final bool alreadyBooked;

  factory Commute.fromJson(Map<String, dynamic> json) {
    return Commute(
      id: json['id'] as String,
      fromAddress: json['from_address'] as String? ?? '',
      toAddress: json['to_address'] as String? ?? '',
      departureAt: DateTime.parse(json['departure_at'] as String).toLocal(),
      poolType: json['pool_type'] as String? ?? 'carpool',

      seatsAvailable: json['seats_available'] as int? ?? 0,
      costPerSeatPaise: json['cost_per_seat_paise'] as int? ?? 0,

      fromLat: (json['from_lat'] as num?)?.toDouble(),
      fromLng: (json['from_lng'] as num?)?.toDouble(),
      toLat: (json['to_lat'] as num?)?.toDouble(),
      toLng: (json['to_lng'] as num?)?.toDouble(),

      seatsTotal: json['seats_total'] as int?,
      status: json['status'] as String?,

      driverName: json['driver_name'] as String?,

      driverRating: _parseDouble(json['driver_rating']),
      driverRatingCount: _parseInt(json['driver_rating_count']),

      womenOnly: json['women_only'] as bool? ?? false,
      alreadyBooked: json['already_booked'] as bool? ?? false,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String get costDisplay {
    if (costPerSeatPaise <= 0) return 'Free';
    return '₹${(costPerSeatPaise / 100).toStringAsFixed(0)}/seat';
  }
}
