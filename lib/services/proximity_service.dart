import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'location_service.dart';
import 'destination_storage_service.dart';
import 'alarm_service.dart';

class ProximityService {
  static ProximityService? _instance;
  ProximityService._internal();
  
  static ProximityService get instance {
    _instance ??= ProximityService._internal();
    return _instance!;
  }

  final LocationService _locationService = LocationService.instance;
  final DestinationStorageService _storageService = DestinationStorageService();
  final AlarmService _alarmService = AlarmService.instance;
  
  StreamSubscription<Position>? _positionSubscription;
  final Set<String> _triggeredDestinations = <String>{};

  Future<void> startProximityMonitoring() async {
    if (_positionSubscription != null) {
      return;
    }

    if (!await _locationService.isLocationPermissionGranted()) {
      await _locationService.requestLocationPermission();
    }

    _positionSubscription = _locationService.getPositionStream().listen(
      _onLocationUpdate,
      onError: (error) {
        // Location stream error: $error
      },
    );

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    
    await Workmanager().registerPeriodicTask(
      "proximity-check",
      "proximityCheck",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  Future<void> stopProximityMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await Workmanager().cancelByUniqueName("proximity-check");
  }

  Future<void> _onLocationUpdate(Position position) async {
    final destinations = await _storageService.getActiveDestinations();
    
    for (final destination in destinations) {
      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        destination.latitude,
        destination.longitude,
      );
      
      final isWithin = distance <= destination.radiusInMeters;

      // Debug: Print proximity check results
      print('Proximity check - ${destination.name}: distance=${distance.toInt()}m, radius=${destination.radiusInMeters.toInt()}m, within=$isWithin');

      if (isWithin && !_triggeredDestinations.contains(destination.id)) {
        _triggeredDestinations.add(destination.id);
        print('Triggering alarm for ${destination.name}');
        await _alarmService.triggerDestinationAlarm(destination);
      } else if (!isWithin && _triggeredDestinations.contains(destination.id)) {
        _triggeredDestinations.remove(destination.id);
        print('Removing ${destination.name} from triggered list');
      }
    }
  }

  // Method to manually check proximity with current position
  Future<void> checkProximityManually(Position position) async {
    await _onLocationUpdate(position);
  }

  void resetTriggeredDestinations() {
    _triggeredDestinations.clear();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case "proximityCheck":
        await _performBackgroundProximityCheck();
        break;
    }
    return Future.value(true);
  });
}

Future<void> _performBackgroundProximityCheck() async {
  final locationService = LocationService.instance;
  final storageService = DestinationStorageService();
  final alarmService = AlarmService.instance;

  final position = await locationService.getCurrentPosition();
  if (position == null) return;

  final destinations = await storageService.getActiveDestinations();
  
  for (final destination in destinations) {
    final isWithin = locationService.isWithinRadius(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
      destination.radiusInMeters,
    );

    if (isWithin) {
      await alarmService.triggerDestinationAlarm(destination);
    }
  }
}