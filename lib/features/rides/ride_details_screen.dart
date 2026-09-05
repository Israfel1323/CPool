import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';

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

  String _formatName(String name) {
    return name
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildVehicleDetailsCard() {
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
              ],
            ),
          ),
        ],
      ),
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
  // Booking IDs for which we have already shown a request popup.
  final Set<String> _handledPendingBookingIds = {};

  bool _requestDialogOpen = false;
  int _boardedPassengerCount = 0;

  @override
  void initState() {
    super.initState();

    _ride = Map<String, dynamic>.from(widget.ride);

    _passengersFuture = widget.isDriver
        ? _api.getPassengers(_ride['id'])
        : Future.value([]);

    _refreshRide();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshRide(),
    );
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

      if (!mounted) return;

      List<dynamic>? latestPassengers;

      if (widget.isDriver) {
        latestPassengers = await _api.getPassengers(latestRide['id']);
      }

      if (!mounted) return;

      setState(() {
        _ride = latestRide;

        if (widget.isDriver) {
          _boardedPassengerCount = latestPassengers!
              .where(
                (passenger) =>
                    (passenger['status'] ?? '').toString().toLowerCase() ==
                    'boarded',
              )
              .length;

          _passengersFuture = Future.value(latestPassengers);
        }
      });

      if (widget.isDriver) {
        await _checkForPendingPassengerRequests();
      }

      final status = (_ride['status'] ?? '').toString().toLowerCase();

      if (status == 'completed') {
        _refreshTimer?.cancel();

        if (!_ratingFlowShown) {
          _ratingFlowShown = true;

          await Future.delayed(const Duration(milliseconds: 500));

          if (!mounted) return;

          await _startRatingFlow();
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

        // Show only one request at a time.
        break;
      }
    } catch (e) {
      debugPrint('Unable to check pending passenger requests: $e');
    }
  }

  Future<void> _showPassengerRequestDialog(
    Map<String, dynamic> passenger,
  ) async {
    if (!mounted || _requestDialogOpen) return;

    _requestDialogOpen = true;

    final bookingId = passenger['booking_id']?.toString();
    final passengerName =
        passenger['display_name']?.toString().trim().isNotEmpty == true
        ? passenger['display_name'].toString()
        : 'A passenger';

    final seats = passenger['seats'] ?? 1;
    final passengerInstitution =
        passenger['institution_name']?.toString().trim() ?? '';

    final passengerAvatarUrl = passenger['avatar_url']?.toString().trim() ?? '';

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
            content: Column(
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

                Text(
                  _formatName(passengerName),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                if (passengerInstitution.isNotEmpty) ...[
                  const SizedBox(height: 4),

                  Text(
                    passengerInstitution.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              ],
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
                  ? '$passengerName has been accepted.'
                  : '$passengerName has been rejected.',
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

      setState(() {
        _ride = {..._ride, 'status': 'completed'};
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      if (!_ratingFlowShown) {
        _ratingFlowShown = true;
        await _startRatingFlow();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to complete ride: $e')));
    }
  }

  Future<void> _startRatingFlow() async {
    try {
      final commuteId = _ride['id'].toString();

      final data = await _api.getRatingEligible(commuteId);

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
              final isWideLayout = constraints.maxWidth >= 800;

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
                    '📅 ${DateFormat('dd MMM yyyy • hh:mm a').format(departure)}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _ride['pool_type'] == 'bikepool'
                        ? '🏍️ Bikepool'
                        : '🚗 Carpool',
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '💺 Seats Available: '
                    '${_ride['seats_available']} / ${_ride['seats_total']}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '💰 ₹${(_ride['cost_per_seat_paise'] ?? 0) ~/ 100} per seat',
                  ),
                ],
              );

              if (!isWideLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rideInfo,

                    const SizedBox(height: 16),

                    if (!widget.isDriver) _buildVehicleDetailsCard(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: rideInfo),

                  if (!widget.isDriver) ...[
                    const SizedBox(width: 40),

                    Expanded(flex: 4, child: _buildVehicleDetailsCard()),
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

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(
                            passenger['display_name']?.toString() ??
                                'Passenger',
                          ),
                          subtitle: Text(
                            passengerStatus == 'confirmed'
                                ? 'Passenger confirmed • Enter OTP to onboard'
                                : passengerStatus == 'boarded'
                                ? 'Passenger boarded'
                                : passengerStatus == 'pending'
                                ? 'Waiting for your response'
                                : passenger['status']?.toString() ?? 'Unknown',
                          ),
                          trailing: status != 'started'
                              ? passengerStatus == 'pending'
                                    ? Wrap(
                                        spacing: 4,
                                        children: [
                                          IconButton(
                                            tooltip: 'Accept',
                                            icon: const Icon(
                                              Icons.check_circle,
                                            ),
                                            onPressed: () async {
                                              try {
                                                await _api.acceptBooking(
                                                  _ride['id'],
                                                  passenger['booking_id']
                                                      .toString(),
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
                                          ),
                                          IconButton(
                                            tooltip: 'Reject',
                                            icon: const Icon(Icons.cancel),
                                            onPressed: () async {
                                              try {
                                                await _api.rejectBooking(
                                                  _ride['id'],
                                                  passenger['booking_id']
                                                      .toString(),
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
                                          ),
                                        ],
                                      )
                                    : passengerStatus == 'confirmed'
                                    ? FilledButton(
                                        onPressed: () =>
                                            _showPassengerOtpDialog(passenger),
                                        child: const Text('Enter OTP'),
                                      )
                                    : passengerStatus == 'boarded'
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Boarded',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null
                              : null,
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
                    try {
                      await _api.bookCommute(_ride['id']);

                      if (!mounted) return;

                      Navigator.of(context).pop(true);
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to book ride: $e')),
                      );
                    }
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
