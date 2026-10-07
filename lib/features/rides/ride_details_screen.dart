import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../chat/chat_screen.dart';
import '../safety/trip_safety_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  final bool isDriver;
  final bool embedded;
  final VoidCallback? onRideEnded;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    required this.isDriver,
    this.embedded = false,
    this.onRideEnded,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final _api = ApiClient();

  Future<void> _callPhoneNumber({
    required String phoneNumber,
    required String personName,
  }) async {
    final cleanedNumber = phoneNumber.trim();

    if (cleanedNumber.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$personName does not have a phone number available.'),
        ),
      );

      return;
    }

    final uri = Uri(scheme: 'tel', path: cleanedNumber);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the phone dialer.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start the call: $e')));
    }
  }

  String _formatName(String name) {
    return name
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildDriverRating() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final ratingValue = _ride['driver_rating'];
    final ratingCountValue = _ride['driver_rating_count'];

    final rating = ratingValue is num
        ? ratingValue.toDouble()
        : double.tryParse(ratingValue?.toString() ?? '');

    final ratingCount = ratingCountValue is num
        ? ratingCountValue.toInt()
        : int.tryParse(ratingCountValue?.toString() ?? '') ?? 0;

    if (rating == null || ratingCount == 0) {
      return Row(
        children: [
          Icon(
            Icons.star_border_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            'New',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 17, color: Colors.amber),
        const SizedBox(width: 5),
        Text(
          '${rating.toStringAsFixed(1)} · $ratingCount '
          '${ratingCount == 1 ? 'rating' : 'ratings'}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _interestList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((interest) => Map<String, dynamic>.from(interest))
        .where(
          (interest) => interest['name']?.toString().trim().isNotEmpty == true,
        )
        .toList();
  }

  Widget _buildInterestSection({
    required String title,
    required List<Map<String, dynamic>> interests,
    IconData icon = Icons.interests_outlined,
  }) {
    if (interests.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withValues(alpha: 0.16)),
                ),
                child: Text(
                  interest['name'].toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInterests() {
    final driverInterests = _interestList(_ride['driver_interests']);
    final commonInterests = _interestList(_ride['common_interests']);

    if (driverInterests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (commonInterests.isNotEmpty)
          _buildInterestSection(
            title: '${commonInterests.length} interests in common',
            interests: commonInterests,
            icon: Icons.handshake_outlined,
          ),
        if (commonInterests.isNotEmpty &&
            commonInterests.length < driverInterests.length)
          const SizedBox(height: 10),
        if (commonInterests.length < driverInterests.length)
          _buildInterestSection(
            title: 'Driver interests',
            interests: driverInterests,
          ),
      ],
    );
  }

  Widget _buildVehicleDetailsCard({required String bookingStatus}) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final vehicleType = (_ride['vehicle_type'] ?? _ride['pool_type'] ?? 'car')
        .toString()
        .toLowerCase();

    final isBike =
        vehicleType.contains('bike') || vehicleType.contains('motorcycle');

    final vehicleName = (_ride['vehicle_name'] ?? '').toString().trim();

    final vehicleNumber = (_ride['vehicle_number'] ?? '').toString().trim();

    final vehicleColor = (_ride['vehicle_color'] ?? '').toString().trim();

    final driverName = (_ride['driver_name'] ?? '').toString().trim();
    final driverInstitution = (_ride['driver_institution'] ?? '')
        .toString()
        .trim();
    final driverPhone = (_ride['driver_phone_number'] ?? '').toString().trim();

    if (vehicleName.isEmpty &&
        vehicleNumber.isEmpty &&
        vehicleColor.isEmpty &&
        driverName.isEmpty) {
      return const SizedBox.shrink();
    }

    final vehicleDescription = [
      if (vehicleColor.isNotEmpty) vehicleColor,
      if (vehicleName.isNotEmpty) vehicleName,
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedVehicle(isBike: isBike, color: primary),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vehicleNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      vehicleNumber.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                if (vehicleNumber.isNotEmpty && vehicleDescription.isNotEmpty)
                  const SizedBox(height: 7),

                if (vehicleDescription.isNotEmpty)
                  Text(
                    vehicleDescription.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                if (driverName.isNotEmpty) ...[
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: primary,
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          _formatName(driverName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Padding(
                    padding: const EdgeInsets.only(left: 21),
                    child: _buildDriverRating(),
                  ),
                ],

                if (driverInstitution.isNotEmpty) ...[
                  const SizedBox(height: 2),

                  Padding(
                    padding: const EdgeInsets.only(left: 21),
                    child: Text(
                      driverInstitution.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                if (!widget.isDriver &&
                    _interestList(_ride['driver_interests']).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildDriverInterests(),
                ],

                if (bookingStatus == 'confirmed') ...[
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      if (driverPhone.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final driverId = (_ride['driver_id'] ?? '')
                                  .toString()
                                  .trim();

                              if (driverId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to open driver chat.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatScreen(
                                    commuteId: _ride['id'].toString(),
                                    participantId: driverId,
                                    participantName: _formatName(driverName),
                                  ),
                                ),
                              );

                              if (!mounted) return;

                              await _refreshRide();
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                            ),
                            label: Builder(
                              builder: (context) {
                                final driverId = (_ride['driver_id'] ?? '')
                                    .toString()
                                    .trim();

                                final unreadCount =
                                    _unreadChatCounts[driverId] ?? 0;

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Chat'),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : unreadCount.toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerRating(Map<String, dynamic> passenger) {
    final theme = Theme.of(context);
    final ratingValue = passenger['passenger_rating'];
    final ratingCountValue = passenger['passenger_rating_count'];

    final rating = ratingValue is num
        ? ratingValue.toDouble()
        : double.tryParse(ratingValue?.toString() ?? '');

    final ratingCount = ratingCountValue is num
        ? ratingCountValue.toInt()
        : int.tryParse(ratingCountValue?.toString() ?? '') ?? 0;

    if (rating == null || ratingCount == 0) {
      return Row(
        children: [
          Icon(
            Icons.star_border_rounded,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            'New',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 5),
        Text(
          '${rating.toStringAsFixed(1)} · $ratingCount '
          '${ratingCount == 1 ? 'rating' : 'ratings'}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildRideProgressCard({
    required String status,
    required bool isDriver,
    required bool hasConfirmedBooking,
    required bool hasPendingBooking,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    String currentTitle;
    String currentSubtitle;
    IconData currentIcon;

    if (status == 'started') {
      currentTitle = 'Ride in Progress';
      currentSubtitle = isDriver
          ? 'You are currently driving this ride.'
          : 'Your ride is currently in progress.';
      currentIcon = Icons.directions_car_filled_rounded;
    } else if (status == 'completed') {
      currentTitle = 'Ride Completed';
      currentSubtitle = 'This ride has been completed successfully.';
      currentIcon = Icons.check_circle_rounded;
    } else if (status == 'cancelled') {
      currentTitle = 'Ride Cancelled';
      currentSubtitle = 'This ride is no longer active.';
      currentIcon = Icons.cancel_rounded;
    } else if (!isDriver && hasPendingBooking) {
      currentTitle = 'Waiting for Driver';
      currentSubtitle =
          'Your booking request is waiting for the driver to respond.';
      currentIcon = Icons.hourglass_top_rounded;
    } else if (!isDriver && hasConfirmedBooking) {
      currentTitle = 'Ride Confirmed';
      currentSubtitle =
          'Your seat has been confirmed. Waiting for the ride to start.';
      currentIcon = Icons.event_available_rounded;
    } else if (status == 'full') {
      currentTitle = 'Ride Ready';
      currentSubtitle = 'All available seats have been filled.';
      currentIcon = Icons.groups_rounded;
    } else {
      currentTitle = 'Waiting for Passengers';
      currentSubtitle = isDriver
          ? 'Your ride is open and waiting for passengers.'
          : 'This ride is currently accepting passengers.';
      currentIcon = Icons.person_add_alt_1_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(currentIcon, color: primary, size: 26),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(currentSubtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  late Map<String, dynamic> _ride;
  late Future<List<dynamic>> _passengersFuture;

  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _ratingFlowShown = false;
  List<dynamic> _currentPassengers = [];
  final Map<String, int> _unreadChatCounts = {};
  final Set<String> _handledPendingBookingIds = {};

  bool _requestDialogOpen = false;
  bool _bookingRejectionHandled = false;
  int _boardedPassengerCount = 0;

  @override
  void initState() {
    super.initState();

    _ride = Map<String, dynamic>.from(widget.ride);

    _passengersFuture = widget.isDriver
        ? _api.getPassengers(_ride['id']).then((passengers) {
            _currentPassengers = passengers;
            return passengers;
          })
        : Future.value([]);

    _refreshRide();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshRide(),
    );
  }

  String _passengerStateSignature(List<dynamic>? passengers) {
    if (passengers == null) return '';

    return passengers
        .map((passenger) {
          if (passenger is! Map) return passenger.toString();

          return [
            passenger['booking_id']?.toString() ?? '',
            passenger['id']?.toString() ?? '',
            passenger['status']?.toString() ?? '',
            passenger['phone_number']?.toString() ?? '',
            passenger['boarding_otp']?.toString() ?? '',
          ].join('|');
        })
        .join('||');
  }

  Future<void> _refreshRide() async {
    if (_refreshing) return;

    _refreshing = true;

    try {
      final updatedRide = await _api.getCommute(_ride['id']);

      Map<String, dynamic> latestRide = {..._ride, ...updatedRide};

      try {
        final activeRideResult = await _api.getActiveRide();

        if (activeRideResult['active'] == true &&
            activeRideResult['commute'] != null) {
          final activeRide = Map<String, dynamic>.from(
            activeRideResult['commute'],
          );

          if (activeRide['id'].toString() == _ride['id'].toString()) {
            latestRide = {...latestRide, ...activeRide};
          }
        }
      } catch (_) {
        // getCommute refresh is still enough if active ride lookup fails.
      }

      List<dynamic>? latestPassengers;

      if (widget.isDriver) {
        latestPassengers = await _api.getPassengers(latestRide['id']);
      }

      Map<String, int> latestUnreadCounts = {};

      try {
        final unreadData = await _api.getUnreadChatMessages();

        final conversations =
            (unreadData['conversations'] as List<dynamic>?) ?? [];

        for (final conversation in conversations) {
          if (conversation is! Map) continue;

          final commuteId = conversation['commute_id']?.toString().trim() ?? '';

          final participantId =
              conversation['participant_id']?.toString().trim() ?? '';

          final unreadCount =
              (conversation['unread_count'] as num?)?.toInt() ?? 0;

          if (commuteId == _ride['id'].toString() &&
              participantId.isNotEmpty &&
              unreadCount > 0) {
            latestUnreadCounts[participantId] = unreadCount;
          }
        }
      } catch (e) {
        debugPrint('Unable to refresh unread chat counts: $e');
      }

      if (!mounted) return;

      final rideChanged = latestRide.toString() != _ride.toString();

      final unreadChanged =
          latestUnreadCounts.toString() != _unreadChatCounts.toString();

      final newPassengerSignature = _passengerStateSignature(latestPassengers);

      bool passengersChanged = false;

      if (widget.isDriver && latestPassengers != null) {
        final currentPassengers = await _passengersFuture.catchError(
          (_) => <dynamic>[],
        );

        passengersChanged =
            _passengerStateSignature(currentPassengers) !=
            newPassengerSignature;
      }

      if (rideChanged || unreadChanged || passengersChanged) {
        if (!mounted) return;

        setState(() {
          _ride = latestRide;

          _unreadChatCounts
            ..clear()
            ..addAll(latestUnreadCounts);

          if (widget.isDriver && latestPassengers != null) {
            _boardedPassengerCount = latestPassengers
                .where(
                  (passenger) =>
                      (passenger['status'] ?? '').toString().toLowerCase() ==
                      'boarded',
                )
                .length;

            _passengersFuture = Future.value(latestPassengers);
          }
        });
      }

      if (widget.isDriver) {
        await _checkForPendingPassengerRequests();
      }

      final status = (_ride['status'] ?? '').toString().toLowerCase();
      final bookingStatus = (_ride['booking_status'] ?? '')
          .toString()
          .toLowerCase();

      if (!widget.isDriver &&
          bookingStatus == 'rejected' &&
          !_bookingRejectionHandled) {
        _bookingRejectionHandled = true;
        _refreshTimer?.cancel();

        if (!mounted) return;

        if (widget.embedded) {
          widget.onRideEnded?.call();
        } else {
          Navigator.of(context).pop(true);
        }

        return;
      }

      if (status == 'completed') {
        _refreshTimer?.cancel();

        if (!_ratingFlowShown) {
          _ratingFlowShown = true;

          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          debugPrint('>>> ABOUT TO START POST-RIDE PAYMENT FLOW');

          final paymentsCompleted = await _startPaymentFlow();

          if (!mounted) return;

          if (paymentsCompleted) {
            debugPrint('>>> ALL REQUIRED PAYMENTS COMPLETED');
            await _startRatingFlow();
          } else {
            _ratingFlowShown = false;
          }
        }

        return;
      }

      if (status == 'cancelled') {
        _refreshTimer?.cancel();

        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;

        if (widget.embedded) {
          widget.onRideEnded?.call();
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint('Unable to refresh ride: $e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _checkForPendingPassengerRequests() async {
    if (!widget.isDriver || _requestDialogOpen) return;

    try {
      final passengers = await _api.getPassengers(_ride['id']);

      if (!mounted) return;

      final pendingPassengers = passengers.where((passenger) {
        final status = (passenger['status'] ?? '').toString().toLowerCase();

        return status == 'pending';
      }).toList();

      for (final passenger in pendingPassengers) {
        final bookingId = passenger['booking_id']?.toString();

        if (bookingId == null || bookingId.isEmpty) {
          continue;
        }

        if (_handledPendingBookingIds.contains(bookingId)) {
          continue;
        }

        _handledPendingBookingIds.add(bookingId);

        await _showPassengerRequestDialog(passenger);

        break;
      }
    } catch (e) {
      debugPrint('Unable to check pending passenger requests: $e');
    }
  }

  List<Map<String, dynamic>> _bookingGuests(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((guest) => Map<String, dynamic>.from(guest))
        .toList();
  }

  Future<void> _showPassengerRequestDialog(
    Map<String, dynamic> passenger,
  ) async {
    if (!mounted || _requestDialogOpen) return;

    _requestDialogOpen = true;

    final bookingId = passenger['booking_id']?.toString();
    final bookedByName =
        passenger['display_name']?.toString().trim().isNotEmpty == true
        ? passenger['display_name'].toString()
        : 'A passenger';
    final travellingMode =
        passenger['travelling_mode']?.toString().trim() ?? 'me';
    final travellingPassengerName =
        travellingMode == 'someone_else' &&
            passenger['travelling_passenger_name']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
        ? passenger['travelling_passenger_name'].toString().trim()
        : bookedByName;
    final travellingPassengerGender =
        passenger['travelling_passenger_gender']?.toString().trim() ??
        passenger['passenger_gender']?.toString().trim() ??
        '';

    final seats = passenger['seats'] ?? 1;
    final guests = _bookingGuests(passenger['guests']);
    final womenOnlyNotice = passenger['women_only_notice'] == true;
    final passengerInstitution =
        passenger['institution_name']?.toString().trim() ?? '';

    final passengerAvatarUrl = passenger['avatar_url']?.toString().trim() ?? '';
    final passengerInterests = _interestList(passenger['passenger_interests']);
    final commonInterests = _interestList(passenger['common_interests']);

    try {
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded),
                SizedBox(width: 10),
                Expanded(child: Text('New Ride Request')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundImage: passengerAvatarUrl.isNotEmpty
                          ? NetworkImage(passengerAvatarUrl)
                          : null,
                      child: passengerAvatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (travellingMode == 'someone_else') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Booked by',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  Text(
                    _formatName(bookedByName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (travellingMode == 'someone_else') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Travelling passenger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatName(travellingPassengerName) +
                          (travellingPassengerGender.isNotEmpty
                              ? ' • ${travellingPassengerGender[0].toUpperCase()}${travellingPassengerGender.substring(1)}'
                              : ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  if (passengerInstitution.isNotEmpty) ...[
                    const SizedBox(height: 6),

                    Text(
                      passengerInstitution.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  _buildPassengerRating(passenger),

                  if (passengerInterests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        commonInterests.isNotEmpty
                            ? '${commonInterests.length} interests in common'
                            : 'Interests',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: passengerInterests.map((interest) {
                          final isCommon = commonInterests.any(
                            (common) =>
                                common['id']?.toString() ==
                                interest['id']?.toString(),
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isCommon
                                  ? Theme.of(dialogContext).colorScheme.primary
                                        .withValues(alpha: 0.10)
                                  : Theme.of(dialogContext)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isCommon
                                    ? Theme.of(dialogContext)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.20)
                                    : Theme.of(
                                        dialogContext,
                                      ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              interest['name'].toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCommon
                                    ? Theme.of(
                                        dialogContext,
                                      ).colorScheme.primary
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Text(
                    'wants to join your ride.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_seat_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('$seats ${seats == 1 ? 'seat' : 'seats'} requested'),
                    ],
                  ),

                  if (guests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Additional passengers',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...guests.map(
                      (guest) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${guest['name'] ?? 'Guest'} • ${(guest['gender'] ?? 'other').toString()}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (womenOnlyNotice) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is a women-only ride. A non-female passenger or guest is included in this request. Please review before accepting.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('reject');
                },
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop('accept');
                },
                child: const Text('Accept'),
              ),
            ],
          );
        },
      );

      if (!mounted || bookingId == null || action == null) return;

      try {
        if (action == 'accept') {
          await _api.acceptBooking(_ride['id'], bookingId);
        } else if (action == 'reject') {
          await _api.rejectBooking(_ride['id'], bookingId);
        }

        if (!mounted) return;

        await _refreshRide();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept'
                  ? '${_formatName(travellingPassengerName)} has been accepted.'
                  : '${_formatName(travellingPassengerName)} has been rejected.',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to update booking: $e')));
      }
    } finally {
      _requestDialogOpen = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<String?> _showCancellationDialog({
    required String title,
    required String message,
  }) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),

                const SizedBox(height: 16),

                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Tell us why you are cancelling...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('No, Keep Ride'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    return result;
  }

  Future<void> _cancelDriverRide() async {
    final reason = await _showCancellationDialog(
      title: 'Cancel Ride?',
      message:
          'Are you sure you want to cancel this ride? Your passengers will be notified.',
    );

    if (reason == null) return;

    try {
      await _api.cancelRide(
        _ride['id'],
        reason: reason.isEmpty ? null : reason,
      );

      if (!mounted) return;

      if (widget.embedded) {
        widget.onRideEnded?.call();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to cancel ride: $e')));
    }
  }

  Future<bool> _showBookingDialog() async {
    final availableSeats = (_ride['seats_available'] as num?)?.toInt() ?? 0;
    final maxSeats = availableSeats.clamp(1, 20);
    var selectedSeats = 1;

    String? accountGender;
    try {
      final profileResponse = await _api.getProfile();
      final profile = profileResponse['profile'];
      if (profile is Map) {
        accountGender = profile['gender']?.toString().trim().toLowerCase();
      }
    } catch (_) {
      // Booking validation below will explain if gender is unavailable.
    }

    // The booking account can either be the person travelling or can book
    // on behalf of someone else. The account holder remains the booking owner.
    var travellingMode = 'me';
    final travellingPassengerNameController = TextEditingController();
    var travellingPassengerGender = 'female';

    final guestNameControllers = <TextEditingController>[];
    final guestGenders = <String>[];

    void syncGuestFields(int guestCount) {
      while (guestNameControllers.length < guestCount) {
        guestNameControllers.add(TextEditingController());
        guestGenders.add('female');
      }

      while (guestNameControllers.length > guestCount) {
        guestNameControllers.removeLast().dispose();
        guestGenders.removeLast();
      }
    }

    syncGuestFields(0);

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              syncGuestFields(selectedSeats - 1);

              final costPerSeatPaise =
                  (_ride['cost_per_seat_paise'] as num?)?.toInt() ?? 0;
              final totalAmount = costPerSeatPaise * selectedSeats;
              final isWomenOnly = _ride['women_only'] == true;

              final primaryPassengerGender = travellingMode == 'someone_else'
                  ? travellingPassengerGender
                  : (accountGender ?? '');

              final primaryPassengerIsMale = primaryPassengerGender == 'male';

              final primaryPassengerIsFemale =
                  primaryPassengerGender == 'female';

              final hasMaleGuest = guestGenders.any(
                (gender) => gender == 'male',
              );

              final womenOnlyBlocked = isWomenOnly && !primaryPassengerIsFemale;

              final hasWomenOnlyDisclosure =
                  isWomenOnly && (primaryPassengerIsMale || hasMaleGuest);

              return AlertDialog(
                title: const Text('Book This Ride'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Who is travelling?',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          value: 'me',
                          groupValue: travellingMode,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              travellingMode = value;
                            });
                          },
                          title: const Text('Me'),
                          subtitle: const Text(
                            'I am the primary passenger for this booking.',
                          ),
                          secondary: const Icon(Icons.person_outline),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'someone_else',
                          groupValue: travellingMode,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              travellingMode = value;
                            });
                          },
                          title: const Text('Someone else'),
                          subtitle: const Text(
                            'I am booking the ride for another person.',
                          ),
                          secondary: const Icon(Icons.group_outlined),
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (travellingMode == 'someone_else') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Travelling passenger',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter the person who will actually be travelling. '
                                  'They will occupy the first seat.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: travellingPassengerNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: travellingPassengerGender,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    prefixIcon: Icon(Icons.wc_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Text('Female'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Text('Other'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setDialogState(() {
                                      travellingPassengerGender = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        const Text(
                          'How many people are travelling under this booking?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_seat_outlined),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Seats',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove seat',
                                onPressed: selectedSeats > 1
                                    ? () {
                                        setDialogState(() {
                                          selectedSeats--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '$selectedSeats',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add seat',
                                onPressed: selectedSeats < maxSeats
                                    ? () {
                                        setDialogState(() {
                                          selectedSeats++;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          '$availableSeats seat(s) available',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),

                        if (selectedSeats > 1) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Additional passengers',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add the people travelling in the remaining seats. '
                            'Guests do not need a CPool account.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),

                          ...List.generate(selectedSeats - 1, (index) {
                            final controller = guestNameControllers[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Additional passenger ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: controller,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: const InputDecoration(
                                        labelText: 'Full name',
                                        prefixIcon: Icon(Icons.person_outline),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      value: guestGenders[index],
                                      decoration: const InputDecoration(
                                        labelText: 'Gender',
                                        prefixIcon: Icon(Icons.wc_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text('Female'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text('Male'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'other',
                                          child: Text('Other'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setDialogState(() {
                                          guestGenders[index] = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],

                        if (womenOnlyBlocked) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    primaryPassengerGender.isEmpty
                                        ? 'This is a women-only ride. Select your gender in Profile before booking.'
                                        : 'This is a women-only ride. Only a female travelling passenger can book this ride.',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (hasWomenOnlyDisclosure) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.30),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This is a women-only ride. A non-female additional passenger will be disclosed to the driver.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_outlined),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Total booking amount',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '₹${_amountRupees(totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: womenOnlyBlocked
                        ? null
                        : () async {
                            if (travellingMode == 'someone_else') {
                              final travellingName =
                                  travellingPassengerNameController.text.trim();

                              if (travellingName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter the name of the travelling passenger.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (travellingName.length > 100) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Travelling passenger name must be 100 characters or less.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            for (
                              var index = 0;
                              index < guestNameControllers.length;
                              index++
                            ) {
                              final guestName = guestNameControllers[index].text
                                  .trim();

                              if (guestName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Enter the name for Additional passenger ${index + 1}.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (guestName.length > 100) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Additional passenger ${index + 1} name must be 100 characters or less.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            final guests = List.generate(
                              guestNameControllers.length,
                              (index) => <String, String>{
                                'name': guestNameControllers[index].text.trim(),
                                'gender': guestGenders[index],
                              },
                            );

                            try {
                              await _api.bookCommute(
                                _ride['id'].toString(),
                                seats: selectedSeats,
                                guests: guests,
                                travellingMode: travellingMode,
                                travellingPassengerName:
                                    travellingMode == 'someone_else'
                                    ? travellingPassengerNameController.text
                                          .trim()
                                    : null,
                                travellingPassengerGender:
                                    travellingMode == 'someone_else'
                                    ? travellingPassengerGender
                                    : null,
                              );

                              if (!mounted) return;

                              Navigator.of(dialogContext).pop(true);
                            } catch (e) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unable to book ride: $e'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.event_available),
                    label: const Text('Book Ride'),
                  ),
                ],
              );
            },
          );
        },
      );

      return result == true;
    } finally {
      travellingPassengerNameController.dispose();

      for (final controller in guestNameControllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _cancelPassengerBooking() async {
    final reason = await _showCancellationDialog(
      title: 'Cancel Your Booking?',
      message:
          'Are you sure you want to cancel your booking? You will lose your seat on this ride.',
    );

    if (reason == null) return;

    try {
      await _api.cancelBooking(
        _ride['id'],
        reason: reason.isEmpty ? null : reason,
      );

      if (!mounted) return;

      if (widget.embedded) {
        widget.onRideEnded?.call();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to cancel booking: $e')));
    }
  }

  Future<void> _startRide() async {
    if (_boardedPassengerCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need at least one boarded passenger before starting the ride.',
          ),
        ),
      );
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Ride?'),
          content: const Text(
            'Are all boarded passengers ready? Once the ride starts, no new passengers can join.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not Yet'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) return;

    try {
      await _api.startRide(_ride['id']);

      await _refreshRide();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride has started. Have a safe journey!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start ride: $e')));
    }
  }

  Future<void> _showPassengerOtpDialog(Map<String, dynamic> passenger) async {
    final otpController = TextEditingController();

    final passengerName =
        passenger['display_name']?.toString().trim().isNotEmpty == true
        ? passenger['display_name'].toString()
        : 'Passenger';

    final bookingId = passenger['booking_id']?.toString();

    if (bookingId == null || bookingId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to find this passenger booking.'),
          ),
        );
      }
      return;
    }

    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Onboard $passengerName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Passenger confirmed. Enter the 4-digit OTP shown by the passenger to onboard them.',
                  ),

                  const SizedBox(height: 18),

                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0000',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final otp = otpController.text.trim();

                          if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid 4-digit OTP.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                          });

                          try {
                            await _api.verifyPassengerOtp(
                              commuteId: _ride['id'].toString(),
                              bookingId: bookingId,
                              otp: otp,
                            );

                            if (!mounted) return;

                            Navigator.of(dialogContext).pop(true);
                          } on DioException catch (e) {
                            if (!mounted) return;

                            setDialogState(() {
                              isVerifying = false;
                            });

                            final responseData = e.response?.data;

                            final errorMessage =
                                responseData is Map &&
                                    responseData['error'] != null
                                ? responseData['error'].toString()
                                : 'Unable to verify OTP. Please try again.';

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMessage)),
                            );
                          } catch (_) {
                            if (!mounted) return;

                            setDialogState(() {
                              isVerifying = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to verify OTP. Please try again.',
                                ),
                              ),
                            );
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify & Onboard'),
                ),
              ],
            );
          },
        );
      },
    );

    otpController.dispose();

    if (verified == true && mounted) {
      await _refreshRide();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$passengerName has boarded successfully.')),
      );
    }
  }

  Future<void> _completeRide() async {
    try {
      await _api.completeRide(_ride['id']);

      if (!mounted) return;

      _refreshTimer?.cancel();

      setState(() {
        _ride = {..._ride, 'status': 'completed'};
      });

      if (_ratingFlowShown) return;

      _ratingFlowShown = true;

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      debugPrint('>>> ABOUT TO START DRIVER PAYMENT FLOW');

      final paymentsCompleted = await _startPaymentFlow();

      if (!mounted) return;

      if (!paymentsCompleted) {
        _ratingFlowShown = false;
        return;
      }

      debugPrint('>>> ALL REQUIRED PAYMENTS COMPLETED');

      await _startRatingFlow();
    } catch (e) {
      if (!mounted) return;

      _ratingFlowShown = false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to complete ride: $e')));
    }
  }

  Future<bool> _startPaymentFlow() async {
    try {
      if (widget.isDriver) {
        return await _showDriverPaymentDialog();
      }

      return await _showPassengerPaymentDialog();
    } catch (e) {
      debugPrint('Payment flow error: $e');

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load payment options: $e')),
      );

      return false;
    }
  }

  int _amountRupees(dynamic amountPaise) {
    final paise = (amountPaise as num?)?.toInt() ?? 0;
    return (paise / 100).round();
  }

  Future<bool> _showPassengerPaymentDialog() async {
    final bookingId = (_ride['booking_id'] ?? '').toString().trim();

    if (bookingId.isEmpty) {
      throw Exception('Unable to find your booking for this ride.');
    }

    var selectedMethod = (_ride['payment_method'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    var paymentStatus = (_ride['payment_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (paymentStatus == 'received') {
      return true;
    }

    final amount = _amountRupees(_ride['cost_per_seat_paise']);

    Timer? refreshTimer;
    StateSetter? dialogSetState;
    BuildContext? activeDialogContext;
    var dialogOpen = true;
    var waitingForDriver = selectedMethod == 'cash';

    final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        activeDialogContext = dialogContext;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;

            final isCash = selectedMethod == 'cash';
            final isUpi = selectedMethod == 'upi';

            return AlertDialog(
              title: const Text('Ride Completed', textAlign: TextAlign.center),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      waitingForDriver
                          ? Icons.hourglass_top_rounded
                          : Icons.payments_rounded,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      waitingForDriver
                          ? 'Waiting for your driver'
                          : 'Pay your driver',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Amount: ₹$amount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (waitingForDriver && isCash)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Give the cash to your driver. Your driver will confirm once the payment is received.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose payment method',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RadioListTile<String>(
                        value: 'cash',
                        groupValue: selectedMethod.isEmpty
                            ? null
                            : selectedMethod,
                        onChanged: waitingForDriver
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedMethod = value;
                                });
                              },
                        title: const Text('Cash'),
                        subtitle: const Text('Pay the driver in cash'),
                        secondary: const Icon(Icons.payments_outlined),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: 'upi',
                        groupValue: selectedMethod.isEmpty
                            ? null
                            : selectedMethod,
                        onChanged: waitingForDriver
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedMethod = value;
                                });
                              },
                        title: const Text('UPI / QR'),
                        subtitle: const Text('Pay using any UPI app'),
                        secondary: const Icon(Icons.qr_code_2_rounded),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isCash) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Give the exact amount to your driver. The driver will confirm when the cash is received.',
                          ),
                        ),
                      ],
                      if (isUpi) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ask your driver to show their UPI QR, scan it with your preferred UPI app, complete the payment, then tap “I’ve Paid”.',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                if (waitingForDriver)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Waiting for driver confirmation…',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: selectedMethod.isEmpty
                        ? null
                        : () async {
                            try {
                              await _api.setPaymentMethod(
                                commuteId: _ride['id'].toString(),
                                bookingId: bookingId,
                                paymentMethod: selectedMethod,
                              );

                              if (!dialogContext.mounted) return;

                              if (selectedMethod == 'cash') {
                                setDialogState(() {
                                  waitingForDriver = true;
                                });
                                return;
                              }

                              final completed = await _api
                                  .completeBookingPayment(
                                    commuteId: _ride['id'].toString(),
                                    bookingId: bookingId,
                                  );

                              paymentStatus =
                                  (completed['booking']?['payment_status'] ??
                                          'received')
                                      .toString()
                                      .toLowerCase();

                              if (!dialogContext.mounted) return;

                              Navigator.of(
                                dialogContext,
                              ).pop(paymentStatus == 'received');
                            } catch (e) {
                              if (!dialogContext.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unable to update payment: $e'),
                                ),
                              );
                            }
                          },
                    child: Text(isCash ? 'Confirm Cash Payment' : 'I’ve Paid'),
                  ),
              ],
            );
          },
        );
      },
    );

    refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!dialogOpen) return;

      try {
        final latestRide = await _api.getCommute(_ride['id']);

        final latestStatus = (latestRide['payment_status'] ?? '')
            .toString()
            .toLowerCase();

        if (!dialogOpen) return;

        paymentStatus = latestStatus;

        if (latestStatus == 'received') {
          dialogOpen = false;
          refreshTimer?.cancel();

          final currentDialogContext = activeDialogContext;

          if (currentDialogContext != null && currentDialogContext.mounted) {
            Navigator.of(currentDialogContext).pop(true);
          }

          return;
        }

        final serverPaymentMethod = (latestRide['payment_method'] ?? '')
            .toString()
            .toLowerCase();

        if (serverPaymentMethod.isNotEmpty) {
          selectedMethod = serverPaymentMethod;

          if (serverPaymentMethod == 'cash') {
            waitingForDriver = true;
          }
        }

        if (dialogSetState != null) {
          dialogSetState!(() {});
        }
      } catch (e) {
        debugPrint('Passenger payment refresh error: $e');
      }
    });

    final result = await dialogFuture;

    dialogOpen = false;
    refreshTimer?.cancel();

    if (paymentStatus == 'received') {
      return true;
    }

    return result == true;
  }

  Future<bool> _showDriverPaymentDialog() async {
    var payments = await _api.getRidePayments(_ride['id'].toString());

    bool allPaid() {
      return payments.isNotEmpty &&
          payments.every(
            (payment) =>
                (payment['payment_status'] ?? '').toString().toLowerCase() ==
                'received',
          );
    }

    if (allPaid()) {
      return true;
    }

    Timer? refreshTimer;
    StateSetter? dialogSetState;
    var dialogOpen = true;

    final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogSetState = setDialogState;

            return AlertDialog(
              title: const Text(
                'Collect Payments',
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 460,
                child: payments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No boarded passengers found.'),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Collect each passenger’s payment. Ratings will open after everyone has paid.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            ...payments.map((payment) {
                              final name = _formatName(
                                payment['display_name']?.toString() ??
                                    'Passenger',
                              );
                              final amount = _amountRupees(
                                payment['amount_paise'],
                              );
                              final method = (payment['payment_method'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final status = (payment['payment_status'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final received = status == 'received';

                              String methodText;
                              IconData methodIcon;

                              if (method == 'cash') {
                                methodText = 'Cash';
                                methodIcon = Icons.payments_outlined;
                              } else if (method == 'upi') {
                                methodText = 'UPI / QR';
                                methodIcon = Icons.qr_code_2_rounded;
                              } else {
                                methodText = 'Payment method not selected';
                                methodIcon = Icons.help_outline_rounded;
                              }

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹$amount',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(methodIcon, size: 18),
                                        const SizedBox(width: 7),
                                        Expanded(child: Text(methodText)),
                                        if (received)
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 19,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Paid',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (!received && method == 'cash') ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () async {
                                            try {
                                              await _api.completeBookingPayment(
                                                commuteId: _ride['id']
                                                    .toString(),
                                                bookingId: payment['booking_id']
                                                    .toString(),
                                              );

                                              payments = await _api
                                                  .getRidePayments(
                                                    _ride['id'].toString(),
                                                  );

                                              if (dialogOpen &&
                                                  dialogSetState != null) {
                                                dialogSetState!(() {});
                                              }

                                              if (allPaid() &&
                                                  dialogOpen &&
                                                  dialogSetState != null) {
                                                dialogSetState!(() {});
                                              }
                                            } catch (e) {
                                              if (!context.mounted) return;

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Unable to confirm payment: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text('Payment Received'),
                                        ),
                                      ),
                                    ],
                                    if (!received && method == 'upi')
                                      const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text(
                                          'Waiting for the passenger to complete the UPI payment.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (!received && method.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 10),
                                        child: Text(
                                          'Waiting for the passenger to choose Cash or UPI.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton(
                  onPressed: allPaid()
                      ? () {
                          Navigator.of(dialogContext).pop(true);
                        }
                      : null,
                  child: const Text('Continue to Rating'),
                ),
              ],
            );
          },
        );
      },
    );

    refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!dialogOpen) return;

      try {
        final latest = await _api.getRidePayments(_ride['id'].toString());

        if (!dialogOpen || dialogSetState == null) return;

        payments = latest;
        dialogSetState!(() {});
      } catch (e) {
        debugPrint('Payment refresh error: $e');
      }
    });

    final result = await dialogFuture;

    dialogOpen = false;
    refreshTimer.cancel();

    return result == true;
  }

  Future<void> _startRatingFlow() async {
    try {
      final commuteId = _ride['id'].toString();

      final data = await _api.getRatingEligible(commuteId);
      debugPrint('>>> DRIVER/PASSENGER RATING DATA: $data');

      if (!mounted) return;

      final role = (data['role'] ?? '').toString().toLowerCase();

      final rawPeople = data['people'] ?? [];

      final people = List<Map<String, dynamic>>.from(
        rawPeople.whereType<Map>(),
      );

      final peopleToRate = people.where((person) {
        return person['already_rated'] != true;
      }).toList();

      String result;

      if (peopleToRate.isEmpty) {
        result = 'submitted';
      } else if (role == 'driver') {
        result = await _showPassengersRatingDialog(
          people: peopleToRate,
          commuteId: commuteId,
        );
      } else {
        result = await _showRatingDialog(
          role: 'passenger',
          person: peopleToRate.first,
          commuteId: commuteId,
        );
      }

      debugPrint('>>> RATING RESULT: $result');

      if (!mounted) return;

      debugPrint('RATING FLOW RESULT: $result');
      debugPrint('SHOWING THANK YOU DIALOG');

      await _showRideFinishedDialog(
        deferredRating: result == 'later',
        role: role == 'driver' ? 'driver' : 'passenger',
      );

      debugPrint('THANK YOU DIALOG CLOSED');

      if (!mounted) return;

      if (widget.embedded) {
        widget.onRideEnded?.call();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Rating flow error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load rating options: $e')),
      );
    }
  }

  Future<void> _showRideFinishedDialog({
    required bool deferredRating,
    required String role,
  }) async {
    if (!mounted) return;

    final personLabel = role == 'driver' ? 'passengers' : 'driver';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final primary = theme.colorScheme.primary;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    deferredRating
                        ? Icons.schedule_rounded
                        : Icons.favorite_rounded,
                    color: primary,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  deferredRating
                      ? 'Thanks for choosing CPool!'
                      : 'Thanks for rating!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  deferredRating
                      ? 'No worries! You can rate your $personLabel later from the Profile section.'
                      : 'Thanks for choosing CPool. Have a great day!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _showRatingDialog({
    required String role,
    required Map<String, dynamic> person,
    required String commuteId,
  }) async {
    int selectedRating = 0;
    bool isSubmitting = false;

    final personName = person['display_name']?.toString() ?? 'User';

    final title = role == 'driver'
        ? 'Rate passenger – $personName'
        : 'Rate your driver';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title, textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    personName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;

                      return IconButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedRating = starNumber;
                                });
                              },
                        icon: Icon(
                          selectedRating >= starNumber
                              ? Icons.star
                              : Icons.star_border,
                          size: 36,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  if (selectedRating > 0)
                    Text(
                      '$selectedRating / 5',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop('later');
                        },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: selectedRating == 0 || isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await _api.submitRating(
                              commuteId: commuteId,
                              ratedId: person['id'].toString(),
                              score: selectedRating,
                            );

                            if (!dialogContext.mounted) return;

                            debugPrint('>>> RATING SUBMIT: popping submitted');

                            Navigator.of(dialogContext).pop('submitted');
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });

                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to submit rating: $e'),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? 'later';
  }

  Future<String> _showPassengersRatingDialog({
    required List<Map<String, dynamic>> people,
    required String commuteId,
  }) async {
    final ratings = <String, int>{};

    for (final person in people) {
      ratings[person['id'].toString()] = 0;
    }

    bool isSubmitting = false;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allRated = ratings.values.every(
              (rating) => rating >= 1 && rating <= 5,
            );

            return AlertDialog(
              title: const Text(
                'Rate your passengers',
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your ratings help keep CPool safe and reliable.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      ...people.map((person) {
                        final personId = person['id'].toString();

                        final personName =
                            person['display_name']?.toString() ?? 'Passenger';

                        final selectedRating = ratings[personId] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                personName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starNumber = index + 1;

                                      return IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: isSubmitting
                                            ? null
                                            : () {
                                                setDialogState(() {
                                                  ratings[personId] =
                                                      starNumber;
                                                });
                                              },
                                        icon: Icon(
                                          selectedRating >= starNumber
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 32,
                                        ),
                                      );
                                    }),
                                  ),
                                  if (selectedRating > 0)
                                    Text(
                                      '$selectedRating/5',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop('later');
                        },
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: !allRated || isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            for (final person in people) {
                              final personId = person['id'].toString();

                              await _api.submitRating(
                                commuteId: commuteId,
                                ratedId: personId,
                                score: ratings[personId]!,
                              );
                            }

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop('submitted');
                            return;
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });

                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to submit ratings: $e'),
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit ratings'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? 'later';
  }

  Widget _buildPassengerOtpCard({
    required String bookingStatus,
    required String boardingOtp,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (widget.isDriver) {
      return const SizedBox.shrink();
    }

    if (bookingStatus == 'confirmed' && boardingOtp.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Icon(Icons.verified_user_rounded, size: 30, color: primary),

            const SizedBox(height: 10),

            Text(
              'Booking Confirmed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Show this OTP to your driver to board',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primary.withValues(alpha: 0.30)),
              ),
              child: Text(
                boardingOtp,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (bookingStatus == 'boarded') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: primary, size: 28),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                'You have boarded',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final departure =
        DateTime.tryParse(_ride['departure_at']?.toString() ?? '') ??
        DateTime.now();

    final status = (_ride['status'] ?? '').toString().toLowerCase();

    final bookingStatus = (_ride['booking_status'] ?? '')
        .toString()
        .toLowerCase();

    final isActive =
        status == 'open' || status == 'full' || status == 'started';

    final isAcceptingBookings = status == 'open';

    final bool hasConfirmedBooking = bookingStatus == 'confirmed';
    final bool hasPendingBooking = bookingStatus == 'pending';
    final bool hasBoardedBooking = bookingStatus == 'boarded';

    final boardingOtp = (_ride['boarding_otp'] ?? '').toString().trim();

    final rideRoleText = widget.isDriver
        ? 'You are driving this ride'
        : hasBoardedBooking
        ? 'You have boarded this ride'
        : hasConfirmedBooking
        ? 'Your booking is confirmed'
        : hasPendingBooking
        ? 'Your booking request is pending'
        : 'You haven\'t joined this ride yet';

    final rideRoleIcon = widget.isDriver
        ? Icons.directions_car_rounded
        : hasBoardedBooking
        ? Icons.check_circle_rounded
        : hasConfirmedBooking
        ? Icons.verified_rounded
        : hasPendingBooking
        ? Icons.hourglass_top_rounded
        : Icons.person_add_alt_1_rounded;

    final rideStatusText = switch (status) {
      'open' => 'Waiting for passengers',
      'full' => 'Ride is full',
      'started' => 'Ride in progress',
      'completed' => 'Ride completed',
      'cancelled' => 'Ride cancelled',
      _ => 'Ride active',
    };

    final content = RefreshIndicator(
      onRefresh: _refreshRide,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.embedded) ...[
            Text(
              'Your Current Ride',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              rideStatusText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  rideRoleIcon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    rideRoleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              // Keep the details and driver card stacked until there is genuinely
              // enough horizontal space for the interests section as well.
              // This prevents the driver card from squeezing the ride details
              // on narrower desktop/tablet/web layouts.
              final isWideLayout = constraints.maxWidth >= 1200;

              final rideInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_ride['from_address'].toString().split(',').first} → '
                    '${_ride['to_address'].toString().split(',').first}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    '${DateFormat('dd MMM yyyy • hh:mm a').format(departure)}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _ride['pool_type'] == 'bikepool' ? 'Bikepool' : 'Carpool',
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Seats Available: '
                    '${_ride['seats_available']} / ${_ride['seats_total']}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '₹${(_ride['cost_per_seat_paise'] ?? 0) ~/ 100} per seat',
                  ),
                ],
              );

              if (!isWideLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rideInfo,

                    const SizedBox(height: 16),

                    if (!widget.isDriver)
                      _buildVehicleDetailsCard(bookingStatus: bookingStatus),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: rideInfo),

                  if (!widget.isDriver) ...[
                    const SizedBox(width: 40),

                    Expanded(
                      flex: 4,
                      child: _buildVehicleDetailsCard(
                        bookingStatus: bookingStatus,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          if (!widget.isDriver &&
              (hasConfirmedBooking || hasBoardedBooking)) ...[
            const SizedBox(height: 16),

            _buildPassengerOtpCard(
              bookingStatus: bookingStatus,
              boardingOtp: boardingOtp,
            ),
          ],

          const SizedBox(height: 20),

          _buildRideProgressCard(
            status: status,
            isDriver: widget.isDriver,
            hasConfirmedBooking: hasConfirmedBooking,
            hasPendingBooking: hasPendingBooking,
          ),

          const SizedBox(height: 24),

          if (widget.isDriver)
            FutureBuilder<List<dynamic>>(
              future: _passengersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Unable to load passengers: ${snapshot.error}');
                }

                final passengers = snapshot.data ?? [];

                if (passengers.isEmpty) {
                  return const Text('No passengers have joined this ride yet.');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Passengers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ...passengers.map((passenger) {
                      final passengerStatus = (passenger['status'] ?? '')
                          .toString()
                          .toLowerCase();

                      final passengerName =
                          passenger['display_name']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? passenger['display_name'].toString()
                          : 'Passenger';

                      final passengerInstitution =
                          passenger['institution_name']?.toString().trim() ??
                          '';

                      final passengerAvatarUrl =
                          passenger['avatar_url']?.toString().trim() ?? '';
                      final seats = passenger['seats'] ?? 1;
                      final guests = _bookingGuests(passenger['guests']);
                      final womenOnlyNotice =
                          passenger['women_only_notice'] == true;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundImage:
                                        passengerAvatarUrl.isNotEmpty
                                        ? NetworkImage(passengerAvatarUrl)
                                        : null,
                                    child: passengerAvatarUrl.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _formatName(passengerName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              if (passengerInstitution.isNotEmpty)
                                Text(
                                  passengerInstitution.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),

                              if (passengerInstitution.isNotEmpty)
                                const SizedBox(height: 4),

                              _buildPassengerRating(passenger),

                              const SizedBox(height: 4),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_seat_outlined,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$seats ${seats == 1 ? 'seat' : 'seats'} requested',
                                  ),
                                ],
                              ),

                              if (guests.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                ...guests.map(
                                  (guest) => Text(
                                    'Guest: ${guest['name'] ?? 'Guest'} • ${(guest['gender'] ?? 'other').toString()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],

                              if (womenOnlyNotice) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Women-only ride: review non-female passenger/guest before accepting.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 4),

                              Text(
                                passengerStatus == 'confirmed'
                                    ? 'Passenger confirmed • Enter OTP to onboard'
                                    : passengerStatus == 'boarded'
                                    ? 'Passenger boarded'
                                    : passengerStatus == 'pending'
                                    ? 'Waiting for your response'
                                    : passenger['status']?.toString() ??
                                          'Unknown',
                              ),

                              const SizedBox(height: 12),

                              if (passengerStatus == 'pending' &&
                                  status != 'started')
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _api.acceptBooking(
                                            _ride['id'],
                                            passenger['booking_id'].toString(),
                                          );

                                          await _refreshRide();

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${passenger['display_name'] ?? 'Passenger'} has been accepted.',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Unable to accept passenger: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.check_circle,
                                        size: 18,
                                      ),
                                      label: const Text('Accept'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await _api.rejectBooking(
                                            _ride['id'],
                                            passenger['booking_id'].toString(),
                                          );

                                          await _refreshRide();

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${passenger['display_name'] ?? 'Passenger'} has been rejected.',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Unable to reject passenger: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.cancel, size: 18),
                                      label: const Text('Reject'),
                                    ),
                                  ],
                                ),

                              if (passengerStatus == 'confirmed')
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final phoneNumber =
                                            passenger['phone_number']
                                                ?.toString()
                                                .trim() ??
                                            '';

                                        final passengerName =
                                            passenger['display_name']
                                                ?.toString()
                                                .trim() ??
                                            'Passenger';

                                        _callPhoneNumber(
                                          phoneNumber: phoneNumber,
                                          personName: passengerName,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.call_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Call'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final passengerId =
                                            passenger['id']
                                                ?.toString()
                                                .trim() ??
                                            '';

                                        final passengerName =
                                            passenger['display_name']
                                                ?.toString()
                                                .trim() ??
                                            'Passenger';

                                        if (passengerId.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Unable to open passenger chat.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ChatScreen(
                                              commuteId: _ride['id'].toString(),
                                              participantId: passengerId,
                                              participantName: _formatName(
                                                passengerName,
                                              ),
                                            ),
                                          ),
                                        );

                                        if (!mounted) return;

                                        await _refreshRide();
                                      },
                                      icon: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 18,
                                      ),
                                      label: Builder(
                                        builder: (context) {
                                          final unreadCount =
                                              _unreadChatCounts[passenger['id']
                                                  ?.toString()
                                                  .trim()] ??
                                              0;

                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('Chat'),
                                              if (unreadCount > 0) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 20,
                                                        minHeight: 20,
                                                      ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    unreadCount > 99
                                                        ? '99+'
                                                        : unreadCount
                                                              .toString(),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    if (status != 'started')
                                      FilledButton(
                                        onPressed: () =>
                                            _showPassengerOtpDialog(passenger),
                                        child: const Text('Enter OTP'),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),

          if (!widget.isDriver && isActive) ...[
            const SizedBox(height: 24),

            if (isAcceptingBookings &&
                (bookingStatus.isEmpty ||
                    bookingStatus == 'none' ||
                    bookingStatus == 'not_booked'))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final booked = await _showBookingDialog();

                    if (!booked || !mounted) return;

                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.event_available),
                  label: const Text('Book Ride'),
                ),
              ),

            if (bookingStatus == 'pending') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your booking request is waiting for the driver.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelPassengerBooking,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Booking Request'),
                ),
              ),
            ],

            if (bookingStatus == 'confirmed' &&
                (status == 'open' || status == 'full'))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _cancelPassengerBooking,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Booking'),
                ),
              ),

            if (bookingStatus == 'rejected')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your booking request was not accepted.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if (widget.isDriver && isActive) ...[
            const SizedBox(height: 24),

            if (status != 'started' && _boardedPassengerCount > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startRide,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Ride'),
                ),
              ),

            if (status != 'started' && _boardedPassengerCount > 0)
              const SizedBox(height: 12),

            if (status == 'started')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeRide,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Ride'),
                ),
              ),

            if (status == 'started') const SizedBox(height: 12),
            if (status == 'started')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TripSafetyScreen(commuteId: _ride['id'].toString()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Trip Safety'),
                ),
              ),

            if (status == 'started') const SizedBox(height: 12),
            if (status == 'open' || status == 'full')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _cancelDriverRide,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Ride'),
                ),
              ),
          ],
          if (!widget.isDriver && status == 'started' && hasBoardedBooking) ...[
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TripSafetyScreen(commuteId: _ride['id'].toString()),
                    ),
                  );
                },
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Trip Safety'),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: content,
    );
  }
}

class _AnimatedVehicle extends StatefulWidget {
  final bool isBike;
  final Color color;

  const _AnimatedVehicle({required this.isBike, required this.color});

  @override
  State<_AnimatedVehicle> createState() => _AnimatedVehicleState();
}

class _AnimatedVehicleState extends State<_AnimatedVehicle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final movement = (_controller.value - 0.5) * 4;

        return Transform.translate(
          offset: Offset(movement, 0),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.isBike
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_filled_rounded,
              size: 32,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}
