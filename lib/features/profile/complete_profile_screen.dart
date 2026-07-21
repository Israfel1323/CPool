import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../shell/main_shell.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class CompleteProfileScreen extends StatefulWidget {
  
  final bool isEditing;
  final Map<String, dynamic>? profile;

  const CompleteProfileScreen({
    super.key,
    this.isEditing = false,
    this.profile,
  });

  @override
  State<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
      
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();

bool _loading = false;
Uint8List? _selectedImageBytes;
XFile? _selectedImageFile;

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
void initState() {
  super.initState();

  if (widget.isEditing && widget.profile != null) {
    _fullNameController.text =
        widget.profile?['full_name'] ?? '';

    _phoneController.text =
        widget.profile?['phone_number'] ?? '';

    _rollNumberController.text =
        widget.profile?['roll_number'] ?? '';

    _selectedBranch =
        widget.profile?['branch'] ?? 'CSE';

    _selectedYear =
        widget.profile?['admission_year'] ?? 2023;
  }
}
  @override
  void dispose() {
    _fullNameController.dispose();
    _rollNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
Future<void> _submitProfile() async {
  if (!_formKey.currentState!.validate()) {
  return;
}
  setState(() {
    _loading = true;
  });

  try {
    String? avatarUrl;

if (_selectedImageFile != null) {
  avatarUrl = await _api.uploadProfilePhoto(_selectedImageFile!);
}
    await _api.updateProfile(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      branch: _selectedBranch,
      rollNumber: _rollNumberController.text.trim().toUpperCase(),
      admissionYear: _selectedYear,
      avatarUrl: avatarUrl,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      widget.isEditing
          ? "Profile updated successfully! 🎉"
          : "Profile completed successfully! 🎉",
    ),
  ),
);

    if (widget.isEditing) {
  Navigator.pop(context, true);
} else {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const MainShell(),
    ),
  );
}
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
final ImagePicker _picker = ImagePicker();

Future<void> _pickImage() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (image == null) return;

  final bytes = await image.readAsBytes();

setState(() {
  _selectedImageBytes = bytes;
  _selectedImageFile = image;
});
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
  widget.isEditing
      ? "Edit Profile"
      : "Complete Profile",
),
        centerTitle: true,
      ),
      body: SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [

              const SizedBox(height: 10),
              Center(
  child: Column(
    children: [
      GestureDetector(
        onTap: _pickImage,
        child:CircleAvatar(
  radius: 55,
  backgroundImage: _selectedImageBytes != null
      ? MemoryImage(_selectedImageBytes!)
      : null,
  child: _selectedImageBytes == null
      ? const Icon(
          Icons.person,
          size: 55,
        )
      : null,
),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _pickImage,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
  widget.isEditing
      ? "Change Profile Photo"
      : "Add Profile Photo",
),
      ),
    ],
  ),
),

const SizedBox(height: 24),

              Text(
                widget.isEditing
    ? "Edit your Profile"
    : "Welcome to CPool 👋",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
  widget.isEditing
      ? "Update your details anytime."
      : "Let's get your profile ready. This will only take a minute.",
  style: theme.textTheme.bodyMedium,
),

              const SizedBox(height: 32),

              TextFormField(
                controller: _fullNameController,
                validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  },
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
                initialValue: _selectedBranch,
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
                validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your student ID';
  }
  return null;
},
                decoration: const InputDecoration(
                  labelText: "Roll Number",
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                initialValue: _selectedYear,
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
                validator: (value) {
  final phone = value?.trim() ?? '';

  if (phone.isEmpty) {
    return 'Please enter your phone number';
  }

  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
    return 'Enter a valid 10-digit phone number';
  }

  return null;
},
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
    : Text(
        widget.isEditing
    ? "Save Changes"
    : "Save & Continue",
      ),
                ),
              ),
                     ],
          ),
        ),
      ),
    ),
  ),
);
  }
}