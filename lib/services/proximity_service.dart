import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'location_service.dart';
import 'destination_storage_service.dart';
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
  final NotificationService _notificationService = NotificationService.instance;
  
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
      final isWithin = _locationService.isWithinRadius(
        position.latitude,
        position.longitude,
        destination.latitude,
        destination.longitude,
        destination.radiusInMeters,
      );

      if (isWithin && !_triggeredDestinations.contains(destination.id)) {
        _triggeredDestinations.add(destination.id);
        await _notificationService.showDestinationAlarm(destination);
      } else if (!isWithin && _triggeredDestinations.contains(destination.id)) {
        _triggeredDestinations.remove(destination.id);
      }
    }
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
  final notificationService = NotificationService.instance;

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
      await notificationService.showDestinationAlarm(destination);
    }
  }
}