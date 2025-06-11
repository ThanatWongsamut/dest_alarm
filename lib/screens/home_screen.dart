import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
    final updatedDestination = destination.copyWith(isActive: !destination.isActive);
    await _storageService.updateDestination(updatedDestination);
    await _loadDestinations();
  }

  Future<void> _deleteDestination(String id) async {
    await _storageService.deleteDestination(id);
    await _loadDestinations();
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
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleMonitoring,
            tooltip: _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
          ),
        ],
      ),
      body: _destinations.isEmpty
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
          : Column(
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
                            _currentPosition != null ? Icons.location_on : Icons.location_off,
                            color: _currentPosition != null ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current Location',
                            style: TextStyle(
                              color: _currentPosition != null ? Colors.blue : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _locationStatus,
                            style: TextStyle(
                              color: _currentPosition != null ? Colors.blue : Colors.orange,
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
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _destinations.length,
                    itemBuilder: (context, index) {
                      final destination = _destinations[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: destination.isActive ? Colors.green : Colors.grey,
                            child: Icon(
                              destination.isActive ? Icons.location_on : Icons.location_off,
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
                                child: Text(destination.isActive ? 'Deactivate' : 'Activate'),
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDestinationScreen()),
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