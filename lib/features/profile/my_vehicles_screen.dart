import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'become_driver_screen.dart';
import 'models/vehicle.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  final ApiClient _api = ApiClient();

  List<Vehicle> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _loading = true);

    try {
      final vehicles = await _api.getVehicles();

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 403 &&
          e.response?.data is Map &&
          e.response?.data['code'] == 'DRIVER_VERIFICATION_REQUIRED') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BecomeDriverScreen()),
        );
        return;
      }

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?.toString() ??
                'Unable to load your vehicles.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load vehicles: $e')));
    }
  }

  Future<void> _showVehicleForm({Vehicle? vehicle}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VehicleFormSheet(api: _api, vehicle: vehicle),
    );

    if (result == true && mounted) {
      await _loadVehicles();
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete vehicle?'),
          content: Text(
            'Are you sure you want to delete ${vehicle.vehicleName} '
            '(${vehicle.vehicleNumber})?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await _api.deleteVehicle(vehicle.id);

      if (!mounted) return;

      await _loadVehicles();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle deleted.')));
    } on DioException catch (e) {
      if (!mounted) return;

      final message =
          e.response?.data?['error']?.toString() ?? 'Unable to delete vehicle.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  IconData _vehicleIcon(String type) {
    return type == 'bike'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVehicleForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVehicles,
              child: _vehicles.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 80),
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: theme.accent,
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'No vehicles found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Add a vehicle to use when offering rides.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showVehicleForm(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Vehicle'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _vehicles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: theme.accentMuted,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  _vehicleIcon(vehicle.vehicleType),
                                  color: theme.accent,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.vehicleName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      vehicle.vehicleNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        vehicle.vehicleType == 'bike'
                                            ? 'Bike'
                                            : 'Car',
                                        if (vehicle.vehicleColor != null &&
                                            vehicle.vehicleColor!
                                                .trim()
                                                .isNotEmpty)
                                          vehicle.vehicleColor!,
                                      ].join(' • '),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showVehicleForm(vehicle: vehicle);
                                  } else if (value == 'delete') {
                                    _deleteVehicle(vehicle);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Edit'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({required this.api, this.vehicle});

  final ApiClient api;
  final Vehicle? vehicle;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _colorController;

  late String _vehicleType;
  bool _saving = false;

  bool get _editing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();

    final vehicle = widget.vehicle;

    _vehicleType = vehicle?.vehicleType ?? 'car';
    _nameController = TextEditingController(text: vehicle?.vehicleName ?? '');
    _numberController = TextEditingController(
      text: vehicle?.vehicleNumber ?? '',
    );
    _colorController = TextEditingController(text: vehicle?.vehicleColor ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (_editing) {
        await widget.api.updateVehicle(
          vehicleId: widget.vehicle!.id,
          vehicleType: _vehicleType,
          vehicleName: _nameController.text,
          vehicleNumber: _numberController.text,
          vehicleColor: _colorController.text,
        );
      } else {
        await widget.api.addVehicle(
          vehicleType: _vehicleType,
          vehicleName: _nameController.text,
          vehicleNumber: _numberController.text,
          vehicleColor: _colorController.text,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;

      final message =
          e.response?.data?['error']?.toString() ?? 'Unable to save vehicle.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save vehicle: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editing ? 'Edit Vehicle' : 'Add Vehicle',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'bike', child: Text('Bike')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _vehicleType = value);
                        }
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Name',
                  hintText: 'e.g. Honda City',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter vehicle name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _numberController,
                textCapitalization: TextCapitalization.characters,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'e.g. TS09AB1234',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter vehicle number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _colorController,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. White',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter vehicle color';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editing ? 'Save Changes' : 'Add Vehicle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
