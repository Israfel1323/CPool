import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/models/commute.dart';
import '../../core/models/geocode_result.dart';
import '../../core/theme/app_theme.dart';
import '../commutes/offer_ride_screen.dart';
import '../shell/main_shell.dart';
import 'widgets/location_card.dart';
import 'widgets/search_button.dart';
import 'widgets/search_filters.dart';
import 'ride_results_screen.dart';
import '../../core/services/location_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _api = ApiClient();
  final _mapController = MapController();
  bool _loadingLocation = true;

  GeocodeResult? _from;
  GeocodeResult? _to;
  List<GeocodeResult> _suggestions = [];
  List<Commute> _commutes = [];
  bool _searchingGeo = false;
  bool _loadingCommutes = false;
  String? _error;
  Timer? _debounce;
  int _geocodeRequest = 0;
  _ActiveField? _activeField;
  bool _womenOnly = false;
  bool _bikeRide = false;

  DateTime? _departureAt;
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);

    final place = await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (place == null) {
      setState(() => _loadingLocation = false);
      return;
    }

    setState(() {
      _from = place;
      _fromCtrl.text = place.displayName;
      _loadingLocation = false;
    });

    _fitMap();
  }

  void _onSearchChanged(String query, _ActiveField field) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _geocode(query, field);
    });
  }

  Future<void> _geocode(String query, _ActiveField field) async {
    final request = ++_geocodeRequest;

    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _searchingGeo = false;
      });
      return;
    }
    setState(() {
      _searchingGeo = true;
      _activeField = field;
      _error = null;
    });
    try {
      if (!AppConfig.hasApi) {
        setState(() {
          _suggestions = [];
          _error = 'Start API: cd server && npm run dev';
        });
        return;
      }
      final raw = await _api.searchGeocode(query);

      // A slower response from an earlier field/query must not replace the
      // choices for the field the rider is editing now.
      if (!mounted || request != _geocodeRequest || _activeField != field) {
        return;
      }

      setState(() {
        _suggestions = raw
            .map((e) => GeocodeResult.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (!mounted || request != _geocodeRequest || _activeField != field) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _geocodeRequest) {
        setState(() => _searchingGeo = false);
      }
    }
  }

  void _selectPlace(GeocodeResult place) {
    // Invalidate requests that were started before the rider made a choice.
    _geocodeRequest++;

    final field = _activeField;
    if (field == _ActiveField.from) {
      _from = place;
      _fromCtrl.text = place.displayName.split(',').first;
    } else if (field == _ActiveField.to) {
      _to = place;
      _toCtrl.text = place.displayName.split(',').first;
    }
    setState(() {
      _suggestions = [];
      _activeField = null;
    });
    _fitMap();
  }

  void _fitMap() {
    final points = <LatLng>[];
    if (_from != null) points.add(LatLng(_from!.lat, _from!.lon));
    if (_to != null) points.add(LatLng(_to!.lat, _to!.lon));
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 13);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
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

  Future<void> _pickDepartureTime() async {
    final now = DateTime.now();

    final initialDate = _departureAt != null && _departureAt!.isAfter(now)
        ? _departureAt!
        : now;

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day + 30),
      initialDate: DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      ),
    );

    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (!mounted || pickedTime == null) return;

    final departure = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!departure.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future departure time.')),
      );
      return;
    }

    setState(() {
      _departureAt = departure;
    });
  }

  Future<bool> _searchCommutes() async {
    setState(() {
      _loadingCommutes = true;
      _error = null;
    });
    try {
      if (!AppConfig.hasApi) {
        setState(() => _error = 'API not configured');
        return false;
      }
      if (_from == null || _to == null) {
        setState(() {
          _error = 'Please select both locations';
        });
        return false;
      }

      final raw = await _api.listCommutes(
        fromLat: _from!.lat,
        fromLng: _from!.lon,
        toLat: _to!.lat,
        toLng: _to!.lon,
        poolType: _bikeRide ? 'bikepool' : 'carpool',
        womenOnly: _womenOnly,
        departureAt: _departureAt,
      );
      setState(() {
        _commutes = raw
            .map((e) => Commute.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      return true;
    } catch (e) {
      setState(() => _error = e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _loadingCommutes = false);
    }
  }

  LatLng get _mapCenter {
    if (_from != null) return LatLng(_from!.lat, _from!.lon);

    if (_to != null) return LatLng(_to!.lat, _to!.lon);

    return const LatLng(17.4375, 78.4482);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: const CPoolAppBar(title: 'Find a Ride'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Find a Ride",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Find your next ride in seconds.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 24),

                  LocationCard(
                    title: "From",
                    hint: "Current Location",
                    icon: Icons.trip_origin_rounded,
                    controller: _fromCtrl,

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
                            tooltip: 'Refresh location',
                            onPressed: _getCurrentLocation,
                          ),

                    onTap: () =>
                        setState(() => _activeField = _ActiveField.from),
                    onChanged: (value) =>
                        _onSearchChanged(value, _ActiveField.from),
                  ),

                  const SizedBox(height: 20),
                  if (_activeField == _ActiveField.from &&
                      _suggestions.isNotEmpty)
                    _buildSuggestions(),

                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("To"),
                      TextField(
                        controller: _toCtrl,
                        onTap: () {
                          setState(() => _activeField = _ActiveField.to);
                        },
                        onChanged: (value) {
                          _onSearchChanged(value, _ActiveField.to);
                        },
                        decoration: const InputDecoration(
                          hintText: "Search destination",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_activeField == _ActiveField.to &&
                      _suggestions.isNotEmpty)
                    _buildSuggestions(),

                  const SizedBox(height: 20),
                  Text(
                    'Departure',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: _pickDepartureTime,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Departure time',
                        prefixIcon: Icon(Icons.schedule_rounded),
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _departureAt == null
                                  ? 'Any time'
                                  : '${MaterialLocalizations.of(context).formatMediumDate(_departureAt!)} • '
                                        '${TimeOfDay.fromDateTime(_departureAt!).format(context)}',
                            ),
                          ),
                          if (_departureAt != null)
                            IconButton(
                              tooltip: 'Clear departure time',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                setState(() {
                                  _departureAt = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SearchFilters(
                    womenOnly: _womenOnly,
                    bikeRide: _bikeRide,
                    onWomenOnlyChanged: (value) {
                      setState(() {
                        _womenOnly = value;
                      });
                    },
                    onBikeRideChanged: (value) {
                      setState(() {
                        _bikeRide = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),
                  SearchButton(
                    loading: _loadingCommutes,
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      if (_from == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a pickup location'),
                          ),
                        );
                        return;
                      }

                      if (_to == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a destination'),
                          ),
                        );
                        return;
                      }

                      final searchCompleted = await _searchCommutes();

                      if (!mounted || !searchCompleted) return;

                      final booked = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RideResultsScreen(commutes: _commutes),
                        ),
                      );

                      if (!context.mounted) return;

                      if (booked == true) {
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 11,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),

                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.cpool.cpool_app',
                      ),
                      if (_from != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_from!.lat, _from!.lon),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.trip_origin,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      if (_to != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_to!.lat, _to!.lon),
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.place,
                                color: Theme.of(context).colorScheme.primary,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_error != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      child: Material(
                        color: theme.card,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ActiveField { from, to }
