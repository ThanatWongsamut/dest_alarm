import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'location_service.dart';
import 'destination_storage_service.dart';
import 'alarm_service.dart';
import 'notification_service.dart';

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
  final NotificationService _notificationService = NotificationService.instance;
  
  StreamSubscription<Position>? _positionSubscription;
  final Set<String> _triggeredDestinations = <String>{};
  bool _isMonitoring = false;

  Future<void> startProximityMonitoring() async {
    if (_isMonitoring) {
      return;
    }
    
    _isMonitoring = true;

    if (!await _locationService.isLocationPermissionGranted()) {
      await _locationService.requestLocationPermission();
    }

    _positionSubscription = _locationService.getPositionStream().listen(
      _onLocationUpdate,
      onError: (error) {
        print('Location stream error: $error');
        // Try to restart the stream after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (_isMonitoring && _positionSubscription == null) {
            startProximityMonitoring();
          }
        });
      },
      onDone: () {
        print('Location stream ended, restarting...');
        _positionSubscription = null;
        // Restart the stream if monitoring is still active
        if (_isMonitoring) {
          Future.delayed(const Duration(seconds: 2), () {
            startProximityMonitoring();
          });
        }
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

    // Show persistent notification when monitoring starts
    await _notificationService.showPersistentMonitoringNotification();
  }

  Future<void> stopProximityMonitoring() async {
    _isMonitoring = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await Workmanager().cancelByUniqueName("proximity-check");
    
    // Cancel persistent notification when monitoring stops
    await _notificationService.cancelMonitoringNotification();
  }

  bool get isMonitoring => _isMonitoring;

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

      // Keep essential proximity logging for debugging
      if (isWithin) {
        print('Proximity check - ${destination.name}: distance=${distance.toInt()}m, radius=${destination.radiusInMeters.toInt()}m, within=$isWithin');
      }

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