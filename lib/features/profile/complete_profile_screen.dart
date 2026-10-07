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
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();

  bool _loading = false;
  Uint8List? _selectedImageBytes;
  XFile? _selectedImageFile;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _institutionController = TextEditingController();

  // ============================================================
  // EMERGENCY CONTACTS
  // ============================================================

  final List<TextEditingController> _contactNameControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final List<TextEditingController> _contactPhoneControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final List<TextEditingController> _contactRelationshipControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  final List<String?> _emergencyContactIds = [null, null];

  final List<bool> _contactSaving = [false, false];

  bool _loadingEmergencyContacts = false;

  int _selectedYear = 2023;

  String? _selectedGender;
  final List<String> _genders = const ['female', 'male', 'other'];

  final List<int> _years = const [2023, 2024, 2025, 2026];

  static const int _maxInterests = 7;
  final TextEditingController _interestSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _availableInterests = [];
  final Set<int> _selectedInterestIds = {};
  bool _loadingInterests = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.profile != null) {
      _fullNameController.text = widget.profile?['full_name'] ?? '';

      _phoneController.text = widget.profile?['phone_number'] ?? '';

      _rollNumberController.text = widget.profile?['roll_number'] ?? '';

      _branchController.text = (widget.profile?['branch'] ?? '')
          .toString()
          .toUpperCase();

      _institutionController.text = (widget.profile?['institution_name'] ?? '')
          .toString()
          .toUpperCase();

      _selectedYear = widget.profile?['admission_year'] ?? 2023;

      final existingGender = widget.profile?['gender']
          ?.toString()
          .toLowerCase();
      if (_genders.contains(existingGender)) {
        _selectedGender = existingGender;
      }
    }

    _loadInterests();
    _loadEmergencyContacts();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _rollNumberController.dispose();
    _branchController.dispose();
    _institutionController.dispose();
    _phoneController.dispose();
    _interestSearchController.dispose();

    for (final controller in _contactNameControllers) {
      controller.dispose();
    }

    for (final controller in _contactPhoneControllers) {
      controller.dispose();
    }

    for (final controller in _contactRelationshipControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // INTERESTS
  // ============================================================

  Future<void> _loadInterests() async {
    setState(() {
      _loadingInterests = true;
    });

    try {
      // When editing, do not rely on the profile object passed by the
      // previous screen. That object can be stale and may not contain the
      // latest profile_interests rows. Fetch the authoritative profile.
      Map<String, dynamic>? freshProfile;

      if (widget.isEditing) {
        final profileResponse = await _api.getProfile();
        freshProfile =
            Map<String, dynamic>.from(profileResponse['profile'] as Map);
      }

      final interests = await _api.getInterests();

      final parsed = interests
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final existing = freshProfile?['interests'] ?? widget.profile?['interests'];
      final existingIds = <int>{};

      if (existing is List) {
        for (final item in existing) {
          if (item is Map) {
            final id = int.tryParse(item['id']?.toString() ?? '');
            if (id != null) existingIds.add(id);
          } else {
            final id = int.tryParse(item.toString());
            if (id != null) existingIds.add(id);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _availableInterests = parsed;
        _selectedInterestIds
          ..clear()
          ..addAll(existingIds.take(_maxInterests));
        _loadingInterests = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loadingInterests = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ??
                'Unable to load interests.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInterests = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load interests.')),
      );
    }
  }

  void _toggleInterest(int id) {
    setState(() {
      if (_selectedInterestIds.contains(id)) {
        _selectedInterestIds.remove(id);
      } else if (_selectedInterestIds.length < _maxInterests) {
        _selectedInterestIds.add(id);
      }
    });
  }

  List<Map<String, dynamic>> _filteredInterests() {
    final query = _interestSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _availableInterests;

    return _availableInterests.where((interest) {
      final name = interest['name']?.toString().toLowerCase() ?? '';
      final category = interest['category']?.toString().toLowerCase() ?? '';
      return name.contains(query) || category.contains(query);
    }).toList();
  }

  Widget _buildInterestsSection(ThemeData theme) {
    final interests = _filteredInterests();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final interest in interests) {
      final category = interest['category']?.toString() ?? 'Other';
      grouped.putIfAbsent(category, () => []).add(interest);
    }

    const categoryOrder = [
      'Creative',
      'Entertainment',
      'Sports',
      'Technology',
      'Business & Finance',
      'Knowledge',
      'Lifestyle',
      'Gaming',
    ];

    final categories = grouped.keys.toList()
      ..sort((a, b) {
        final ai = categoryOrder.indexOf(a);
        final bi = categoryOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'What are you into?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_selectedInterestIds.length}/$_maxInterests',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose up to 7 interests. We’ll use them to help you find people you’ll enjoy travelling with.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _interestSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search interests',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _interestSearchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _interestSearchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        if (interests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No interests found.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...categories.map((category) {
            final categoryInterests = grouped[category]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryInterests.map((interest) {
                      final id = int.tryParse(interest['id']?.toString() ?? '');
                      if (id == null) return const SizedBox.shrink();

                      final selected = _selectedInterestIds.contains(id);
                      final disabled =
                          !selected &&
                          _selectedInterestIds.length >= _maxInterests;

                      return FilterChip(
                        selected: selected,
                        onSelected: disabled
                            ? null
                            : (_) => _toggleInterest(id),
                        avatar: interest['icon']?.toString().isNotEmpty == true
                            ? Text(interest['icon'].toString())
                            : null,
                        label: Text(interest['name']?.toString() ?? ''),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ============================================================
  // EMERGENCY CONTACT METHODS
  // ============================================================

  Future<void> _loadEmergencyContacts() async {
    setState(() {
      _loadingEmergencyContacts = true;
    });

    try {
      final contacts = await _api.getEmergencyContacts();

      for (int i = 0; i < contacts.length && i < 2; i++) {
        final contact = Map<String, dynamic>.from(contacts[i] as Map);

        _emergencyContactIds[i] = contact['id']?.toString();

        _contactNameControllers[i].text = contact['name']?.toString() ?? '';

        _contactPhoneControllers[i].text =
            contact['phone_number']?.toString() ?? '';

        _contactRelationshipControllers[i].text =
            contact['relationship']?.toString() ?? '';
      }
    } on DioException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ??
                'Unable to load emergency contacts.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load emergency contacts.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmergencyContacts = false;
        });
      }
    }
  }

  bool _validateEmergencyContact(int index) {
    final name = _contactNameControllers[index].text.trim();
    final phone = _contactPhoneControllers[index].text.trim();
    final relationship = _contactRelationshipControllers[index].text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the name for Emergency Contact ${index + 1}.',
          ),
        ),
      );
      return false;
    }

    if (name.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency Contact ${index + 1} name is too long.'),
        ),
      );
      return false;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the phone number for Emergency Contact ${index + 1}.',
          ),
        ),
      );
      return false;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter a valid 10-digit phone number for Emergency Contact ${index + 1}.',
          ),
        ),
      );
      return false;
    }

    if (relationship.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Relationship for Emergency Contact ${index + 1} is too long.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveEmergencyContact(int index) async {
    if (!_validateEmergencyContact(index)) {
      return;
    }

    setState(() {
      _contactSaving[index] = true;
    });

    try {
      final name = _contactNameControllers[index].text.trim();
      final phoneNumber = _contactPhoneControllers[index].text.trim();
      final relationship = _contactRelationshipControllers[index].text.trim();

      Map<String, dynamic> response;

      if (_emergencyContactIds[index] == null) {
        response = await _api.addEmergencyContact(
          name: name,
          phoneNumber: phoneNumber,
          relationship: relationship.isEmpty ? null : relationship,
        );

        final savedContact = Map<String, dynamic>.from(
          response['contact'] as Map,
        );

        _emergencyContactIds[index] = savedContact['id']?.toString();
      } else {
        response = await _api.updateEmergencyContact(
          contactId: _emergencyContactIds[index]!,
          name: name,
          phoneNumber: phoneNumber,
          relationship: relationship.isEmpty ? null : relationship,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency Contact ${index + 1} saved successfully.'),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ??
                'Unable to save emergency contact.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save emergency contact.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _contactSaving[index] = false;
        });
      }
    }
  }

  Future<void> _deleteEmergencyContact(int index) async {
    final contactId = _emergencyContactIds[index];

    if (contactId == null) {
      _clearEmergencyContact(index);
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Emergency Contact?'),
          content: Text(
            'Remove ${_contactNameControllers[index].text.trim()} '
            'from your emergency contacts?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _contactSaving[index] = true;
    });

    try {
      await _api.deleteEmergencyContact(contactId);

      _clearEmergencyContact(index);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emergency Contact ${index + 1} deleted.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ??
                'Unable to delete emergency contact.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete emergency contact.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _contactSaving[index] = false;
        });
      }
    }
  }

  void _clearEmergencyContact(int index) {
    setState(() {
      _emergencyContactIds[index] = null;
      _contactNameControllers[index].clear();
      _contactPhoneControllers[index].clear();
      _contactRelationshipControllers[index].clear();
    });
  }

  Widget _buildEmergencyContactCard(int index) {
    final hasSavedContact = _emergencyContactIds[index] != null;
    final saving = _contactSaving[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency Contact ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasSavedContact)
                  IconButton(
                    tooltip: 'Delete contact',
                    onPressed: saving
                        ? null
                        : () => _deleteEmergencyContact(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller: _contactNameControllers[index],
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactPhoneControllers[index],
              enabled: !saving,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _contactRelationshipControllers[index],
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'Ex: Mother, Father, Friend',
                prefixIcon: Icon(Icons.people_outline),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: saving ? null : () => _saveEmergencyContact(index),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasSavedContact
                            ? Icons.save_outlined
                            : Icons.person_add_alt_1_outlined,
                      ),
                label: Text(hasSavedContact ? 'Save Changes' : 'Save Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

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
        institutionName: _institutionController.text.trim().toUpperCase(),
        branch: _branchController.text.trim().toUpperCase(),
        rollNumber: _rollNumberController.text.trim().toUpperCase(),
        admissionYear: _selectedYear,
        gender: _selectedGender!,
        avatarUrl: avatarUrl,
        interestIds: _selectedInterestIds.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? "Profile updated successfully!"
                : "Profile completed successfully!",
          ),
        ),
      );

      if (widget.isEditing) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ?? 'Something went wrong.',
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
        title: Text(widget.isEditing ? "Edit Profile" : "Complete Profile"),
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

                  // ========================================================
                  // PROFILE PHOTO
                  // ========================================================
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 55,
                            backgroundImage: _selectedImageBytes != null
                                ? MemoryImage(_selectedImageBytes!)
                                : null,
                            child: _selectedImageBytes == null
                                ? const Icon(Icons.person, size: 55)
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
                        : "Welcome to CPool",
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

                  // ========================================================
                  // PERSONAL INFORMATION
                  // ========================================================
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
                    controller: _institutionController,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your institution';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      final uppercaseValue = value.toUpperCase();

                      if (value != uppercaseValue) {
                        _institutionController.value = _institutionController
                            .value
                            .copyWith(
                              text: uppercaseValue,
                              selection: TextSelection.collapsed(
                                offset: uppercaseValue.length,
                              ),
                            );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Institution',
                      prefixIcon: Icon(Icons.school_outlined),
                      hintText: 'Ex: MGIT',
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _branchController,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your branch';
                      }

                      return null;
                    },
                    onChanged: (value) {
                      final uppercaseValue = value.toUpperCase();

                      if (value != uppercaseValue) {
                        _branchController.value = _branchController.value
                            .copyWith(
                              text: uppercaseValue,
                              selection: TextSelection.collapsed(
                                offset: uppercaseValue.length,
                              ),
                            );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                      hintText: 'Ex: CSE',
                    ),
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

                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    items: _genders
                        .map(
                          (gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(
                              gender[0].toUpperCase() + gender.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your gender';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
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
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ========================================================
                  // INTERESTS
                  // ========================================================
                  if (_loadingInterests)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildInterestsSection(theme),
                    const SizedBox(height: 36),
                  ],

                  // ========================================================
                  // EMERGENCY CONTACTS
                  // ========================================================
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Emergency Contacts',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Add up to 2 people you trust and can reach in an emergency.',
                    style: theme.textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 16),

                  if (_loadingEmergencyContacts)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildEmergencyContactCard(0),
                    _buildEmergencyContactCard(1),
                  ],

                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Make sure this number belongs to someone you trust '
                            'and can reach in an emergency.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ========================================================
                  // SAVE PROFILE
                  // ========================================================
                  SizedBox(
                    height: 55,
                    child: FilledButton(
                      onPressed: _loading ? null : _submitProfile,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
