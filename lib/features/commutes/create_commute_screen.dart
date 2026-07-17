import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/models/geocode_result.dart';
import '../../core/providers/auth_provider.dart';

class CreateCommuteScreen extends StatefulWidget {
  const CreateCommuteScreen({super.key, this.from, this.to});

  final GeocodeResult? from;
  final GeocodeResult? to;

  @override
  State<CreateCommuteScreen> createState() => _CreateCommuteScreenState();
}

class _CreateCommuteScreenState extends State<CreateCommuteScreen> {
  final _api = ApiClient();
  String _poolType = 'carpool';
  bool _womenOnly = false;
  int _seats = 3;
  int _costRupees = 50;
  DateTime _departure = DateTime.now().add(const Duration(hours: 2));
  bool _loading = false;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to offer a ride')),
      );
      return;
    }
    if (widget.from == null || widget.to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick From and To on Search first')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.createCommute({
        'from_address': widget.from!.displayName,
        'to_address': widget.to!.displayName,
        'from_lat': widget.from!.lat,
        'from_lng': widget.from!.lon,
        'to_lat': widget.to!.lat,
        'to_lng': widget.to!.lon,
        'pool_type': _poolType,
        'women_only': _womenOnly,
        'seats_total': _seats,
        'cost_per_seat_paise': _costRupees * 100,
        'departure_at': _departure.toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commute created')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!AppConfig.hasApi)
            const Text('Configure API_BASE_URL in .env'),
          ListTile(
            title: const Text('From'),
            subtitle: Text(widget.from?.displayName ?? 'Set on Search tab'),
          ),
          ListTile(
            title: const Text('To'),
            subtitle: Text(widget.to?.displayName ?? 'Set on Search tab'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _poolType,
            decoration: const InputDecoration(labelText: 'Pool type'),
            items: const [
              DropdownMenuItem(value: 'carpool', child: Text('CarPool')),
              DropdownMenuItem(value: 'bikepool', child: Text('BikePool')),
              DropdownMenuItem(value: 'studentpool', child: Text('StudentPool')),
            ],
            onChanged: (v) {
  setState(() {
    _poolType = v ?? 'carpool';

    if (_poolType == 'bikepool') {
      _seats = 1;
    }

    if (_poolType == 'studentpool') {
      _seats = 10;
    }
  });
},
          ),
          SwitchListTile(
            title: const Text('Women only'),
            value: _womenOnly,
            onChanged: (v) => setState(() => _womenOnly = v),
          ),
if (_poolType != 'bikepool')
  Row(
    children: [
      Expanded(
        child: Text('Seats: $_seats'),
      ),
      IconButton(
        onPressed: _seats > 1
            ? () => setState(() => _seats--)
            : null,
        icon: const Icon(Icons.remove),
      ),
      IconButton(
        onPressed: _seats < 6
            ? () => setState(() => _seats++)
            : null,
        icon: const Icon(Icons.add),
      ),
    ],
  ),
  if (_poolType == 'bikepool')
  const ListTile(
    leading: Icon(Icons.info_outline),
    title: Text(
      'Bikepool allows only 1 passenger',
    ),
  ),
          Text('Cost per seat: ₹$_costRupees'),
          Slider(
            value: _costRupees.toDouble(),
            min: 0,
            max: 500,
            divisions: 50,
            label: '₹$_costRupees',
            onChanged: (v) => setState(() => _costRupees = v.round()),
          ),
          ListTile(
            title: const Text('Departure'),
            subtitle: Text(DateFormat.yMMMd().add_jm().format(_departure)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                initialDate: _departure,
              );
              if (!context.mounted || date == null) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_departure),
              );
              if (!context.mounted || time == null) return;
              setState(() {
                _departure = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish commute'),
          ),
        ],
      ),
    );
  }
}
