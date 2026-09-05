import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/models/geocode_result.dart';
import '../../core/providers/auth_provider.dart';
import '../search/widgets/location_card.dart';
import '../../core/services/location_service.dart';
import 'dart:async';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key, this.from, this.to});

  final GeocodeResult? from;
  final GeocodeResult? to;

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final _api = ApiClient();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  GeocodeResult? _from;
  GeocodeResult? _to;

  List<GeocodeResult> _suggestions = [];

  _ActiveField? _activeField;
  bool _searchingGeo = false;
  Timer? _debounce;
  bool _loadingLocation = false;
  String _poolType = 'carpool';
  bool _womenOnly = false;
  int _seats = 3;
  int _costRupees = 50;
  DateTime _departure = DateTime.now().add(const Duration(hours: 2));
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final place = await LocationService.getCurrentLocation();

    if (!mounted || place == null) return;

    setState(() {
      _from = place;
      _fromCtrl.text = place.displayName;
    });
  }

  void _onSearchChanged(String query, _ActiveField field) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _geocode(query, field);
    });
  }

  Future<void> _geocode(String query, _ActiveField field) async {
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _searchingGeo = true;
      _activeField = field;
    });

    try {
      if (!AppConfig.hasApi) {
        setState(() => _suggestions = []);
        return;
      }

      final raw = await _api.searchGeocode(query);

      setState(() {
        _suggestions = raw
            .map((e) => GeocodeResult.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } finally {
      if (mounted) {
        setState(() => _searchingGeo = false);
      }
    }
  }

  void _selectPlace(GeocodeResult place) {
    if (_activeField == _ActiveField.from) {
      _from = place;
      _fromCtrl.text = place.displayName.split(',').first;
    } else {
      _to = place;
      _toCtrl.text = place.displayName.split(',').first;
    }

    setState(() {
      _suggestions = [];
      _activeField = null;
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isSignedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to offer a ride')));
      return;
    }
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and destination'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.createCommute({
        'from_address': _from!.displayName,
        'to_address': _to!.displayName,
        'from_lat': _from!.lat,
        'from_lng': _from!.lon,
        'to_lat': _to!.lat,
        'to_lng': _to!.lon,
        'pool_type': _poolType,
        'women_only': _womenOnly,
        'seats_total': _seats,
        'cost_per_seat_paise': _costRupees * 100,
        'departure_at': _departure.toUtc().toIso8601String(),
      });
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride created successfully')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSuggestions() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            final parts = s.displayName.split(',');

            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(
                parts.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                parts.skip(1).join(',').trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectPlace(s),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!AppConfig.hasApi) const Text('Configure API_BASE_URL in .env'),
          LocationCard(
            trailing: _loadingLocation
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadCurrentLocation,
                  ),

            onTap: () => setState(() => _activeField = _ActiveField.from),

            onChanged: (value) => _onSearchChanged(value, _ActiveField.from),
            title: 'From',
            hint: 'Enter pickup location',
            icon: Icons.my_location,
            controller: _fromCtrl,
          ),

          const SizedBox(height: 16),
          if (_activeField == _ActiveField.from && _suggestions.isNotEmpty)
            _buildSuggestions(),

          const SizedBox(height: 16),

          LocationCard(
            title: 'To',
            hint: 'Enter destination',
            icon: Icons.location_on,
            controller: _toCtrl,
            onTap: () {
              debugPrint("TO TAP");
              setState(() => _activeField = _ActiveField.to);
            },
            onChanged: (value) {
              debugPrint("TO CHANGED: $value");
              _onSearchChanged(value, _ActiveField.to);
            },
          ),
          if (_activeField == _ActiveField.to && _suggestions.isNotEmpty)
            _buildSuggestions(),

          const SizedBox(height: 16),

          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _poolType,
            decoration: const InputDecoration(labelText: 'Pool type'),
            items: const [
              DropdownMenuItem(value: 'carpool', child: Text('CarPool')),
              DropdownMenuItem(value: 'bikepool', child: Text('BikePool')),
            ],
            onChanged: (v) {
              setState(() {
                _poolType = v ?? 'carpool';

                if (_poolType == 'bikepool') {
                  _seats = 1;
                }

                if (_poolType == 'carpool' && _seats == 1) {
                  _seats = 3;
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
                Expanded(child: Text('Seats: $_seats')),
                IconButton(
                  onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: _seats < 6 ? () => setState(() => _seats++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          if (_poolType == 'bikepool')
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bikepool allows only 1 passenger'),
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
                : const Text('Publish ride'),
          ),
        ],
      ),
    );
  }
}

enum _ActiveField { from, to }
