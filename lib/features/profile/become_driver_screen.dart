import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/api/api_client.dart';
import 'screens/verification_pending_screen.dart';
import '../../core/widgets/upload_document_card.dart';
import '../../core/services/driver_verification_service.dart';
import 'screens/verification_success_screen.dart';

class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _formKey = GlobalKey<FormState>();

  final _vehicleNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final DriverVerificationService _verificationService =
      DriverVerificationService();

  String _vehicleType = 'car';
  final _api = ApiClient();

  XFile? _frontLicense;
  XFile? _backLicense;

  bool _submitting = false;
  bool _checkingStatus = true;
  Future<void> _loadDriverStatus() async {
    final status = await _verificationService.getStatus();

    if (!mounted) return;

    switch (status) {
      case DriverVerificationState.pending:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
        );
        return;

      case DriverVerificationState.verified:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const VerificationSuccessScreen(verificationType: 'driver'),
          ),
        );
        return;

      case DriverVerificationState.rejected:
      case DriverVerificationState.notApplied:
        break;
    }

    if (mounted) {
      setState(() {
        _checkingStatus = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_frontLicense == null || _backLicense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both license images.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final frontUrl = await _api.uploadDriverLicense(_frontLicense!, 'front');

      final backUrl = await _api.uploadDriverLicense(_backLicense!, 'back');

      await _api.saveDriverDetails(
        vehicleType: _vehicleType,
        vehicleName: _vehicleNameController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleColor: _vehicleColorController.text.trim(),
        licenseFrontUrl: frontUrl,
        licenseBackUrl: backUrl,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickLicense(bool front) async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    setState(() {
      if (front) {
        _frontLicense = file;
      } else {
        _backLicense = file;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDriverStatus();
    });
  }

  @override
  void dispose() {
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Become a Driver")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Complete your driver profile",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Provide your vehicle details and upload your driving license for verification.",
                ),
                const Text(
                  "Vehicle Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        DropdownButtonFormField<String>(
                          value: _vehicleType,
                          decoration: const InputDecoration(
                            labelText: "Vehicle Type",
                          ),
                          items: const [
                            DropdownMenuItem(value: "car", child: Text("Car")),
                            DropdownMenuItem(
                              value: "bike",
                              child: Text("Bike"),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _vehicleType = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _vehicleNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: "Vehicle Name *",
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your vehicle name";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _vehicleNumberController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: "Vehicle Number *",
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your vehicle number";
                            }

                            if (value.trim().length < 8) {
                              return "Enter a valid vehicle number";
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _vehicleColorController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: "Vehicle Color *",
                            prefixIcon: Icon(Icons.palette),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your vehicle color";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Driver License",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                UploadDocumentCard(
                  title: "Driving License (Front)",
                  subtitle: "PNG • JPG • Max 5 MB",
                  image: _frontLicense,
                  onTap: () => _pickLicense(true),
                ),

                const SizedBox(height: 20),

                UploadDocumentCard(
                  title: "Driving License (Back)",
                  subtitle: "PNG • JPG • Max 5 MB",
                  image: _backLicense,
                  onTap: () => _pickLicense(false),
                ),
                const SizedBox(height: 32),

                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Privacy & Security",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Your driver's license is encrypted and securely stored.\n\n"
                                "Only CPool administrators can access your documents for verification.\n\n"
                                "Your license is never shared with passengers or other users.",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Submit for Verification"),
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
