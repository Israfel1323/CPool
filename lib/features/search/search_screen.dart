import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/models/commute.dart';
import '../../core/models/geocode_result.dart';
import '../../core/theme/app_theme.dart';
import '../commutes/create_commute_screen.dart';
import '../shell/main_shell.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Position? _currentPosition;
  bool _loadingLocation = true;

  GeocodeResult? _from;
  GeocodeResult? _to;
  List<GeocodeResult> _suggestions = [];
  List<Commute> _commutes = [];
  bool _searchingGeo = false;
  bool _loadingCommutes = false;
  String? _error;
  Timer? _debounce;
  _ActiveField? _activeField;
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
  debugPrint('Location function started');

  try {
    final status = await Permission.location.request();

    debugPrint('Permission status: $status');

    if (!status.isGranted) {
      setState(() => _loadingLocation = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint(
      'LAT=${position.latitude}, LNG=${position.longitude}',
    );

    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _loadingLocation = false;
    });

    /*_mapController.move(
      LatLng(position.latitude, position.longitude),
      14,
    );*/
  } catch (e) {
    debugPrint('Location error: $e');

    if (mounted) {
      setState(() => _loadingLocation = false);
    }
  }
}
void _onSearchChanged(
  String query,
  _ActiveField field,
) {
  debugPrint('onSearchChanged: $query');
  _debounce?.cancel();

  _debounce = Timer(
    const Duration(milliseconds: 400),
    () {
      _geocode(query, field);
    },
  );
}
  Future<void> _geocode(String query, _ActiveField field) async {
    debugPrint('geocode called: $query');
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
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
      debugPrint('calling API for: $query');  
final raw = await _api.searchGeocode(query);
      setState(() {
        _suggestions =
            raw.map((e) => GeocodeResult.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searchingGeo = false);
    }
  }

  void _selectPlace(GeocodeResult place) {
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

  Future<void> _searchCommutes() async {
    setState(() {
      _loadingCommutes = true;
      _error = null;
    });
    try {
      if (!AppConfig.hasApi) {
        setState(() => _error = 'API not configured');
        return;
      }
      if (_from == null || _to == null) {
  setState(() {
    _error = 'Please select both locations';
  });
  return;
}

final raw = await _api.listCommutes(
  fromLat: _from!.lat,
  fromLng: _from!.lon,
  toLat: _to!.lat,
  toLng: _to!.lon,
);
      setState(() {
        _commutes =
            raw.map((e) => Commute.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCommutes = false);
    }
  }

  LatLng get _mapCenter {
  if (_from != null) return LatLng(_from!.lat, _from!.lon);

  if (_to != null) return LatLng(_to!.lat, _to!.lon);

  if (_currentPosition != null) {
    return LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  return const LatLng(17.4375, 78.4482);
}

  @override
  Widget build(BuildContext context) {
    final theme = context.cpoolTheme;

    return Scaffold(
      appBar: const CPoolAppBar(title: 'Search'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _fromCtrl,
                  decoration: InputDecoration(
                    hintText: 'From',
                    prefixIcon: const Icon(Icons.trip_origin_rounded),
                    suffixIcon: _searchingGeo && _activeField == _ActiveField.from
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onTap: () => setState(() => _activeField = _ActiveField.from),
                  onChanged: (v) => _onSearchChanged(
                    v,
                      _ActiveField.from,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _toCtrl,
                  decoration: InputDecoration(
                    hintText: 'To',
                    prefixIcon: const Icon(Icons.place_rounded),
                    suffixIcon: _searchingGeo && _activeField == _ActiveField.to
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onTap: () => setState(() => _activeField = _ActiveField.to),
                  onChanged: (v) => _onSearchChanged(
                    v,
                       _ActiveField.to,
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            s.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => _selectPlace(s),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loadingCommutes ? null : _searchCommutes,
                        icon: _loadingCommutes
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                        label: const Text('Find rides'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreateCommuteScreen(
                            from: _from,
                            to: _to,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_road_rounded),
                      tooltip: 'Offer ride',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
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
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.cpool.cpool_app',
                      ),
                      if (_currentPosition != null)
  MarkerLayer(
    markers: [
      Marker(
        point: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        width: 40,
        height: 40,
        child: const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 32,
        ),
      ),
    ],
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
                        child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_commutes.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _commutes.length,
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _commutes[i];
                  return SizedBox(
                    width: 220,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                     child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      c.fromAddress,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge,
    ),
    Text(
      '→ ${c.toAddress}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    ),

    const Spacer(),

    Text(
      c.costDisplay,
      style: Theme.of(context).textTheme.labelLarge,
    ),

    const SizedBox(height: 4),

    Text(
      'Seats: ${c.seatsAvailable}',
      style: Theme.of(context).textTheme.bodySmall,
    ),

    const SizedBox(height: 8),

    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: c.alreadyBooked
          ? null
          : () async {
          try {
            final result = await _api.bookCommute(c.id);

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ride booked successfully',
                ),
              ),
            );

            debugPrint(result.toString());

            await _searchCommutes();
          } catch (e) {
  String message = 'Something went wrong';

  if (e is DioException) {
    message =
        e.response?.data?['error']?.toString() ??
        e.message ??
        message;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
        },
        child: Text(
  c.alreadyBooked
      ? 'Already Booked'
      : 'Book Ride',
),
      ),
    ),
  ],
),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

enum _ActiveField { from, to }
