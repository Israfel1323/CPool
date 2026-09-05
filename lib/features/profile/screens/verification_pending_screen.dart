import 'package:flutter/material.dart';

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({
    super.key,
    this.verificationType = 'driver',
  });

  final String verificationType;

  bool get isDriver => verificationType.toLowerCase() == 'driver';

  String get pageTitle =>
      isDriver ? 'Driver Verification' : 'Identity Verification';

  String get documentText =>
      isDriver ? 'your driving license' : 'your College ID';
  String get featureText => isDriver
      ? 'Once your driver verification is approved, you will be able to offer rides to other CPool users.'
      : 'Once your student verification is approved, you will be able to find and join rides on CPool.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.orange,
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Application Submitted',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                Text(
                  'Your verification request has been submitted successfully.\n\n'
                  'Our team is now reviewing $documentText.\n\n'
                  'Verification usually takes 24–48 hours.\n\n'
                  '$featureText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),

                const SizedBox(height: 35),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Pending Verification',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Return Home'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
