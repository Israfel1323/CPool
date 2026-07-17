import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import 'package:provider/provider.dart';


class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
 @override
  State<VerificationScreen> createState() =>
      _VerificationScreenState();
      
}

class _VerificationScreenState
    extends State<VerificationScreen> {
      final ImagePicker _picker = ImagePicker();
      XFile? _selectedFile;
      bool _uploading = false;
      bool _loadingStatus = true;
Map<String, dynamic>? _verification;
@override
void initState() {
  super.initState();
  _loadVerificationStatus();
}
      Future<void> _pickCollegeId() async {
  final file = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );

  if (file == null) return;

  setState(() {
    _selectedFile = file;
  });
}
Future<void> _uploadDocument() async {
  if (_selectedFile == null) return;

  setState(() {
    _uploading = true;
  });

  try {
    final api = context.read<AuthProvider>().api;

    await api.uploadStudentId(
      _selectedFile!,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Verification request submitted successfully!',
        ),
      ),
    );

    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Upload failed: $e',
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

    final data = await api.getVerificationStatus();

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
    print(_verification);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              Text(
                'Identity Verification',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 10),

              Text(
                'Verify your identity to build trust within the CPool community.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 8),

              Text(
                'Every verification is reviewed manually for your safety.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 22),

              _SectionCard(
                title: 'Benefits',
                children: const [
                _BenefitTile('Unlock verified-only rides'),
_BenefitTile('Display a verified profile badge'),
_BenefitTile('Build trust with fellow commuters'),
                ],
              ),

              const SizedBox(height: 20),

             _SectionCard(
  title: 'College ID Card',
  children: [
    InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickCollegeId,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 24,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_rounded,
              size: 46,
              color: theme.accent,
            ),
            const SizedBox(height: 12),
            Text(
  _selectedFile == null
      ? 'Choose College ID'
      : _selectedFile!.name,
  style: Theme.of(context).textTheme.titleMedium,
  textAlign: TextAlign.center,
),
            const SizedBox(height: 6),
            Text(
  _selectedFile == null
      ? 'PNG • JPG • Maximum 3 MB'
      : '✓ Ready to upload',
  style: Theme.of(context).textTheme.bodySmall,
  textAlign: TextAlign.center,
),
          ],
        ),
      ),
    ),
  ],
),

              const SizedBox(height: 20),

              _SectionCard(
                title: 'Supported Files',
                children: const [
                  _InfoTile('Supported', 'JPG • PNG'),
                  _InfoTile('Maximum Size', '3 MB'),
                ],
              ),
const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
  onPressed: (_selectedFile == null || _uploading)
      ? null
      : _uploadDocument,
  child: _uploading
      ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        )
      : const Text(
          'Submit Verification',
        ),
),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

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
            style: Theme.of(context).textTheme.titleMedium,
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
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.left, this.right);

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(left)),
          Text(
            right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}