import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/destination.dart';
import '../services/destination_storage_service.dart';
import '../services/proximity_service.dart';
import '../services/location_service.dart';
import '../services/alarm_service.dart';
import 'add_destination_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DestinationStorageService _storageService = DestinationStorageService();
  final ProximityService _proximityService = ProximityService.instance;
  final LocationService _locationService = LocationService.instance;
  List<Destination> _destinations = [];
  bool _isMonitoring = false;
  Position? _currentPosition;
  String _locationStatus = 'Getting location...';
  bool _showMap = false;
  final MapController _mapController = MapController();
  Timer? _locationRefreshTimer;
  DateTime? _lastLocationUpdate;
  bool _isRefreshingLocation = false;
  int _refreshIntervalSeconds = 3; // Default 3 seconds

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _getCurrentLocation();
    _startLocationRefreshTimer();
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    final destinations = await _storageService.getDestinations();
    setState(() {
      _destinations = destinations;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isRefreshingLocation = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _lastLocationUpdate = DateTime.now();
          _locationStatus = 'Location updated';
          _isRefreshingLocation = false;
        });
        
        // Check proximity whenever location is updated and monitoring is active
        if (_isMonitoring) {
          _proximityService.checkProximityManually(position);
        }
      } else {
        setState(() {
          _locationStatus = 'Location unavailable';
          _isRefreshingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error';
        _isRefreshingLocation = false;
      });
    }
  }

  void _startLocationRefreshTimer() {
    _locationRefreshTimer?.cancel(); // Cancel existing timer
    _locationRefreshTimer =
        Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
      if (mounted) {
        _getCurrentLocation();
      } else {
        timer.cancel();
      }
    });
  }

  String _getLocationAge() {
    if (_lastLocationUpdate == null) return '';

    final now = DateTime.now();
    final diff = now.difference(_lastLocationUpdate!).inSeconds;

    if (diff < 60) {
      return '${diff}s ago';
    } else if (diff < 3600) {
      return '${(diff / 60).floor()}m ago';
    } else {
      return '${(diff / 3600).floor()}h ago';
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      await _proximityService.stopProximityMonitoring();
      setState(() {
        _isMonitoring = false;
      });
    } else {
      await _proximityService.startProximityMonitoring();
      setState(() {
        _isMonitoring = true;
      });
    }
  }

  Future<void> _toggleDestination(Destination destination) async {
    final updatedDestination =
        destination.copyWith(isActive: !destination.isActive);
    await _storageService.updateDestination(updatedDestination);
    await _loadDestinations();
  }

  Future<void> _deleteDestination(String id) async {
    await _storageService.deleteDestination(id);
    await _loadDestinations();
  }

  void _centerMapOnCurrentLocation() {
    if (_currentPosition != null && _showMap) {
      try {
        _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15,
        );
      } catch (e) {
        // Map not ready yet, ignore
      }
    }
  }

  void _testAlarm() {
    if (_destinations.isNotEmpty) {
      // Use the first destination for testing
      final testDestination = _destinations.first;
      AlarmService.instance.triggerDestinationAlarm(testDestination);
    }
  }

  void _showRefreshSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Refresh Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose how often to update your current location:'),
            const SizedBox(height: 16),
            ...([3, 5, 10, 15, 30].map((seconds) => RadioListTile<int>(
                  title: Text('Every $seconds seconds'),
                  value: seconds,
                  groupValue: _refreshIntervalSeconds,
                  onChanged: (value) {
                    setState(() {
                      _refreshIntervalSeconds = value!;
                    });
                    _startLocationRefreshTimer(); // Restart timer with new interval
                    Navigator.pop(context);
                  },
                ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _checkProximityNow() {
    if (_currentPosition != null) {
      _proximityService.checkProximityManually(_currentPosition!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proximity check performed. Check debug console for details.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No current location available for proximity check.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addTestDestination() async {
    if (_currentPosition != null) {
      final testDestination = Destination(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Destination',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInMeters: 50, // 50 meter radius
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _storageService.saveDestination(testDestination);
      await _loadDestinations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test destination added at current location with 50m radius'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Marker> _buildMapMarkers() {
    List<Marker> markers = [];

    // Add current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
    }

    // Add destination markers
    for (final destination in _destinations) {
      markers.add(
        Marker(
          point: LatLng(destination.latitude, destination.longitude),
          child: Icon(
            destination.isActive ? Icons.location_on : Icons.location_off,
            color: destination.isActive ? Colors.red : Colors.grey,
            size: 35,
          ),
        ),
      );
    }

    return markers;
  }

  List<CircleMarker> _buildMapCircles() {
    List<CircleMarker> circles = [];

    // Add radius circles for active destinations
    for (final destination in _destinations.where((d) => d.isActive)) {
      circles.add(
        CircleMarker(
          point: LatLng(destination.latitude, destination.longitude),
          radius: destination.radiusInMeters,
          useRadiusInMeter: true,
          color: Colors.red.withValues(alpha: 0.2),
          borderColor: Colors.red,
          borderStrokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  Widget _buildStatusHeader() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: _currentPosition != null
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _isRefreshingLocation
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _currentPosition != null
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        )
                      : Icon(
                          _currentPosition != null
                              ? Icons.location_on
                              : Icons.location_off,
                          color: _currentPosition != null
                              ? Colors.blue
                              : Colors.orange,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Location',
                    style: TextStyle(
                      color: _currentPosition != null
                          ? Colors.blue
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _locationStatus,
                        style: TextStyle(
                          color: _currentPosition != null
                              ? Colors.blue
                              : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_lastLocationUpdate != null) ...[
                        Text(
                          _getLocationAge(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Refreshing every ${_refreshIntervalSeconds}s',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (_currentPosition != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                  'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        if (_isMonitoring)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Monitoring active destinations',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Active destinations: ${_destinations.where((d) => d.isActive).length}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapView() {
    return Column(
      children: [
        _buildStatusHeader(),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude)
                      : const LatLng(37.7749, -122.4194),
                  initialZoom: 15,
                  onTap: (tapPosition, point) {
                    // Show destination info on tap
                    _showDestinationInfo(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.dest_alarm',
                  ),
                  CircleLayer(circles: _buildMapCircles()),
                  MarkerLayer(markers: _buildMapMarkers()),
                ],
              ),
            ),
          ),
        ),
        if (_destinations.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_destinations.where((d) => d.isActive).length} active destinations shown on map',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildStatusHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: _destinations.length,
            itemBuilder: (context, index) {
              final destination = _destinations[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        destination.isActive ? Colors.green : Colors.grey,
                    child: Icon(
                      destination.isActive
                          ? Icons.location_on
                          : Icons.location_off,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(destination.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radius: ${destination.radiusInMeters.toInt()}m\n'
                        'Lat: ${destination.latitude.toStringAsFixed(4)}, '
                        'Lng: ${destination.longitude.toStringAsFixed(4)}',
                      ),
                      if (_currentPosition != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Distance: ${_locationService.calculateDistance(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                                destination.latitude,
                                destination.longitude,
                              ).toInt()}m away',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                            destination.isActive ? 'Deactivate' : 'Activate'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'toggle') {
                        _toggleDestination(destination);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(destination);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDestinationInfo(LatLng point) {
    // Find the closest destination to the tapped point
    Destination? closestDestination;
    double minDistance = double.infinity;

    for (final destination in _destinations) {
      final distance = _locationService.calculateDistance(
        point.latitude,
        point.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (distance < 100 && distance < minDistance) {
        // Within 100m
        minDistance = distance;
        closestDestination = destination;
      }
    }

    if (closestDestination != null) {
      _showDestinationBottomSheet(closestDestination);
    }
  }

  void _showDestinationBottomSheet(Destination destination) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  destination.isActive ? Icons.location_on : Icons.location_off,
                  color: destination.isActive ? Colors.red : Colors.grey,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Radius: ${destination.radiusInMeters.toInt()}m'),
            Text(
                'Coordinates: ${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}'),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distance: ${_locationService.calculateDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      destination.latitude,
                      destination.longitude,
                    ).toInt()}m away',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleDestination(destination);
                    },
                    child:
                        Text(destination.isActive ? 'Deactivate' : 'Activate'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(destination);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destination Alarm'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
              if (_showMap && _currentPosition != null) {
                _centerMapOnCurrentLocation();
              }
            },
            tooltip: _showMap ? 'List View' : 'Map View',
          ),
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleMonitoring,
            tooltip: _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          ),
          if (_destinations.isNotEmpty)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'test_alarm',
                  child: Row(
                    children: [
                      Icon(Icons.alarm, size: 20),
                      SizedBox(width: 8),
                      Text('Test Alarm'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh_settings',
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 20),
                      SizedBox(width: 8),
                      Text('Refresh Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'check_proximity',
                  child: Row(
                    children: [
                      Icon(Icons.radar, size: 20),
                      SizedBox(width: 8),
                      Text('Check Proximity Now'),
                    ],
                  ),
                ),
                if (_currentPosition != null)
                  const PopupMenuItem(
                    value: 'add_test_destination',
                    child: Row(
                      children: [
                        Icon(Icons.add_location_alt, size: 20),
                        SizedBox(width: 8),
                        Text('Add Test Destination Here'),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                if (value == 'test_alarm') {
                  _testAlarm();
                } else if (value == 'refresh_settings') {
                  _showRefreshSettings();
                } else if (value == 'check_proximity') {
                  _checkProximityNow();
                } else if (value == 'add_test_destination') {
                  _addTestDestination();
                }
              },
            ),
        ],
      ),
      body: _destinations.isEmpty && !_showMap
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No destinations added yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first destination',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _showMap
              ? _buildMapView()
              : _buildListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AddDestinationScreen()),
          );
          if (result == true) {
            await _loadDestinations();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(Destination destination) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Destination'),
        content: Text('Are you sure you want to delete "${destination.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDestination(destination.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
