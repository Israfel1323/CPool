import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../shell/main_shell.dart';
import 'package:dio/dio.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
      
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();

bool _loading = false;

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController _rollNumberController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  String _selectedBranch = 'CSE';
  int _selectedYear = 2023;

  final List<String> _branches = const [
    'CSE',
    'IT',
    'CSM',
    'CSD',
    'CSB',
    'ECE',
    'EEE',
    'MECH',
    'MCT',
    'MME',
    'CIVIL',
  ];

  final List<int> _years = const [
    2023,
    2024,
    2025,
    2026,
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _rollNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
Future<void> _submitProfile() async {
  setState(() {
    _loading = true;
  });

  try {
    await _api.updateProfile(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      branch: _selectedBranch,
      rollNumber: _rollNumberController.text.trim().toUpperCase(),
      admissionYear: _selectedYear,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile completed successfully! 🎉"),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainShell(),
      ),
    );
  } on DioException catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.response?.data?['error']?.toString() ??
              'Something went wrong.',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Profile"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [

              const SizedBox(height: 10),

              Text(
                "Welcome to CPool 👋",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Complete your profile before you start using CPool.",
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 20),

              TextFormField(
                initialValue: "MGIT",
                enabled: false,
                decoration: const InputDecoration(
                  labelText: "Institution",
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedBranch,
                decoration: const InputDecoration(
                  labelText: "Branch",
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: _branches
                    .map(
                      (branch) => DropdownMenuItem(
                        value: branch,
                        child: Text(branch),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBranch = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _rollNumberController,
                decoration: const InputDecoration(
                  labelText: "Roll Number",
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: const InputDecoration(
                  labelText: "Admission Year",
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: _years
                    .map(
                      (year) => DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: FilledButton(
                  onPressed: _loading ? null : _submitProfile,
                  child: _loading
    ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      )
    : const Text(
        "Complete Profile",
      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}