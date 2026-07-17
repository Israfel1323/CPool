import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _bookingIdCtrl = TextEditingController();
  final _api = ApiClient();
  Razorpay? _razorpay;
  bool _loading = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && AppConfig.hasRazorpay) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    }
  }

  @override
  void dispose() {
    _bookingIdCtrl.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  String? _pendingBookingId;
  String? _pendingOrderId;

  void _onSuccess(PaymentSuccessResponse response) async {
    if (_pendingBookingId == null) return;
    try {
      await _api.confirmPayment(
        bookingId: _pendingBookingId!,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? _pendingOrderId,
      );
      setState(() => _status = 'Payment confirmed');
    } catch (e) {
      setState(() => _status = 'Confirm failed: $e');
    }
  }

  void _onError(PaymentFailureResponse response) {
    setState(() => _status = response.message ?? 'Payment failed');
  }

  Future<void> _pay() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first')),
      );
      return;
    }
    final bookingId = _bookingIdCtrl.text.trim();
    if (bookingId.isEmpty) {
      setState(() => _status = 'Enter a booking ID from a booked ride');
      return;
    }

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final order = await _api.createPaymentOrder(bookingId);
      _pendingBookingId = bookingId;
      _pendingOrderId = order['order_id'] as String?;

      if (kIsWeb) {
        setState(() {
          _status =
              'Web: use Razorpay Checkout script or test on Android/iOS.\nOrder: ${order['order_id']}';
        });
        return;
      }

      if (_razorpay == null || !AppConfig.hasRazorpay) {
        setState(() => _status = 'Set RAZORPAY_KEY_ID in .env');
        return;
      }

      final options = {
        'key': order['key_id'] ?? AppConfig.razorpayKeyId,
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'name': 'CPool',
        'description': order['description'] ?? 'Ride payment',
        'order_id': order['order_id'],
        'prefill': {'email': auth.user?.email ?? ''},
      };
      _razorpay!.open(options);
      setState(() => _status = 'Checkout opened');
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.accentMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Razorpay', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'No monthly fee — you pay only when rides are paid. '
                    'Book a commute first, then pay with the booking ID.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _bookingIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Booking ID',
                hintText: 'From POST /commutes/:id/book',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _pay,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payment_rounded),
              label: const Text('Pay with Razorpay'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
