import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'dart:typed_data';
import 'screens/verification_pending_screen.dart';
import 'screens/verification_success_screen.dart';


class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _frontFile;
  XFile? _backFile;
  Uint8List? _frontBytes;
  Uint8List? _backBytes;

  bool _uploading = false;
  bool _loadingStatus = true;

  Map<String, dynamic>? _verification;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _pickFront() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;

    setState(() {
      _frontFile = file;
      _frontBytes = bytes;
    });
  }

  Future<void> _pickBack() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;

    setState(() {
      _backFile = file;
      _backBytes = bytes;
    });
  }

  void _removeFront() {
    setState(() {
      _frontFile = null;
      _frontBytes = null;
    });
  }

  void _removeBack() {
    setState(() {
      _backFile = null;
      _backBytes = null;
    });
  }

  Future<void> _uploadDocument() async {
    if (_frontFile == null || _backFile == null || _uploading) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final api = context.read<AuthProvider>().api;

      await api.uploadStudentId(frontFile: _frontFile!, backFile: _backFile!);

      if (!mounted) return;

      await _loadVerificationStatus();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification request submitted successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unable to upload your ID. Please try again.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final api = context.read<AuthProvider>().api;

      final data = await api.getVerificationStatus(type: 'student');

      if (!mounted) return;

      setState(() {
        _verification = data;
        _loadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    final status =
        _verification?['data']?['status']?.toString().toLowerCase() ??
        _verification?['status']?.toString().toLowerCase();

    if (_loadingStatus) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: theme.background),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (status == 'pending') {
      return const VerificationPendingScreen(verificationType: 'student');
    }

    if (status == 'approved') {
      return const VerificationSuccessScreen(verificationType: 'student');
    }

    if (status == 'rejected') {
      return _buildRejectedScreen(context);
    }

    return _buildUploadScreen(context);
  }

  Widget _buildUploadScreen(BuildContext context) {
    final theme = context.cpoolTheme;

    final canSubmit = _frontFile != null && _backFile != null && !_uploading;

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: theme.background),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Identity Verification',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Verify your identity to build trust within the CPool community.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 6),

              Text(
                'Upload clear photos of both sides of your college ID.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 24),

              _SectionCard(
                title: 'College ID Card',
                children: [
                  _IdPreviewCard(
                    title: 'Front Side',
                    file: _frontFile,
                    bytes: _frontBytes,
                    onPick: _pickFront,
                    onRemove: _removeFront,
                  ),

                  const SizedBox(height: 20),

                  _IdPreviewCard(
                    title: 'Back Side',
                    file: _backFile,
                    bytes: _backBytes,
                    onPick: _pickBack,
                    onRemove: _removeBack,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title: 'Before You Submit',
                children: const [
                  _BenefitTile(
                    'Make sure your name and photo are clearly visible.',
                  ),
                  _BenefitTile(
                    'Upload the front and back of the same ID card.',
                  ),
                  _BenefitTile('Avoid blurry, dark, or cropped images.'),
                  _BenefitTile('Your document will be manually reviewed.'),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: canSubmit ? _uploadDocument : null,
                  child: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Submit Verification'),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'JPG or PNG • Maximum 5 MB per image',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovedScreen(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: theme.background),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _StatusCard(
              icon: Icons.verified_rounded,
              iconColor: Colors.green,
              title: 'Verification Successful',
              message:
                  'Your identity has been verified successfully. '
                  'You can now use verified features within CPool.',
              buttonText: 'Continue',
              onPressed: () {
                Navigator.of(context).pop();
              },
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(BuildContext context) {
    final theme = context.cpoolTheme;

    final data = _verification?['data'];
    final reason = data?['rejection_reason']?.toString();

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: theme.background),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _SectionCard(
            title: 'Verification Rejected',
            children: [
              const Center(
                child: Icon(Icons.cancel_outlined, size: 64, color: Colors.red),
              ),

              const SizedBox(height: 18),

              Text(
                'Your verification request was rejected.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),

              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 18),

                Text(
                  'Reason',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(reason),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _verification = null;
                      _frontFile = null;
                      _backFile = null;
                      _frontBytes = null;
                      _backBytes = null;
                    });
                  },
                  child: const Text('Submit New Verification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
    required this.theme,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;
  final dynamic theme;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      children: [
        Center(child: Icon(icon, size: 70, color: iconColor)),

        const SizedBox(height: 18),

        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(buttonText),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          ...children,
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),

          const SizedBox(width: 10),

          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _IdPreviewCard extends StatelessWidget {
  const _IdPreviewCard({
    required this.title,
    required this.file,
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final XFile? file;
  final Uint8List? bytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;
    final hasImage = file != null && bytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),

        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage ? theme.accent : theme.border,
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(bytes!, fit: BoxFit.contain),
                    ),

                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRemove,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                file!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: onPick,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: theme.card,
                              side: BorderSide(color: theme.accent),
                              foregroundColor: theme.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                          color: theme.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upload $title',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tap to choose an image',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
