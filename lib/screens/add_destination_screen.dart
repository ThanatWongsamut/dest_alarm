import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/destination.dart';
import '../services/destination_storage_service.dart';
import '../services/location_service.dart';

class AddDestinationScreen extends StatefulWidget {
  const AddDestinationScreen({super.key});

  @override
  State<AddDestinationScreen> createState() => _AddDestinationScreenState();
}

class _AddDestinationScreenState extends State<AddDestinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  
  final DestinationStorageService _storageService = DestinationStorageService();
  final LocationService _locationService = LocationService.instance;
  
  bool _isLoading = false;
  bool _showMap = false;
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        final location = LatLng(position.latitude, position.longitude);
        _updateLocation(location);
      } else {
        _showError('Could not get current location. Please check permissions and GPS.');
      }
    } catch (e) {
      _showError('Error getting location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateLocation(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _latController.text = location.latitude.toStringAsFixed(6);
      _lngController.text = location.longitude.toStringAsFixed(6);
      _updateMapMarkers();
    });
  }

  void _updateMapMarkers() {
    if (_selectedLocation == null) return;
    
    final radius = double.tryParse(_radiusController.text) ?? 100.0;
    
    setState(() {
      _markers = [
        Marker(
          point: _selectedLocation!,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      ];
      
      _circles = [
        CircleMarker(
          point: _selectedLocation!,
          radius: radius,
          useRadiusInMeter: true, // Makes radius scale properly with zoom
          color: Colors.blue.withValues(alpha: 0.2),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
        ),
      ];
    });
  }

  void _toggleMapView() async {
    if (!_showMap && _selectedLocation == null) {
      await _getCurrentLocation();
    }
    setState(() {
      _showMap = !_showMap;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveDestination() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final destination = Destination(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        radiusInMeters: double.parse(_radiusController.text),
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _storageService.saveDestination(destination);
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Error saving destination: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Destination'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Destination Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a destination name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a radius';
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0) {
                    return 'Please enter a valid radius';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (_showMap) {
                    _updateMapMarkers();
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getCurrentLocation,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('Current Location'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleMapView,
                      icon: Icon(_showMap ? Icons.list : Icons.map),
                      label: Text(_showMap ? 'Form View' : 'Map View'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_showMap) ...[
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLocation ?? const LatLng(37.7749, -122.4194),
                        initialZoom: 15,
                        onTap: (tapPosition, point) {
                          _updateLocation(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.dest_alarm',
                        ),
                        CircleLayer(circles: _circles),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap on the map to select a destination. The blue circle shows the alarm radius.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDestination,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Destination'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}