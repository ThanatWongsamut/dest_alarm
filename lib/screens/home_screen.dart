import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/destination.dart';
import '../services/destination_storage_service.dart';
import '../services/proximity_service.dart';
import '../services/location_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _getCurrentLocation();
  }

  Future<void> _loadDestinations() async {
    final destinations = await _storageService.getDestinations();
    setState(() {
      _destinations = destinations;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _locationStatus = 'Location updated';
        });
      } else {
        setState(() {
          _locationStatus = 'Location unavailable';
        });
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error';
      });
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
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15,
      );
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
                  Icon(
                    _currentPosition != null
                        ? Icons.location_on
                        : Icons.location_off,
                    color:
                        _currentPosition != null ? Colors.blue : Colors.orange,
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
                  Text(
                    _locationStatus,
                    style: TextStyle(
                      color: _currentPosition != null
                          ? Colors.blue
                          : Colors.orange,
                      fontSize: 12,
                    ),
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
            child: const Row(
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
