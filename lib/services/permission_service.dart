import 'package:permission_handler/permission_handler.dart';

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted
}

class PermissionService {
  static PermissionService? _instance;
  PermissionService._internal();
  
  static PermissionService get instance {
    _instance ??= PermissionService._internal();
    return _instance!;
  }

  Future<PermissionResult> checkLocationPermission() async {
    final status = await Permission.location.status;
    return _mapPermissionStatus(status);
  }

  Future<PermissionResult> requestLocationPermission() async {
    final status = await Permission.location.request();
    return _mapPermissionStatus(status);
  }

  Future<bool> isLocationPermissionGranted() async {
    final result = await checkLocationPermission();
    return result == PermissionResult.granted;
  }

  Future<bool> shouldShowRequestRationale() async {
    return await Permission.location.shouldShowRequestRationale;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  PermissionResult _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return PermissionResult.granted;
      case PermissionStatus.denied:
        return PermissionResult.denied;
      case PermissionStatus.permanentlyDenied:
        return PermissionResult.permanentlyDenied;
      case PermissionStatus.restricted:
        return PermissionResult.restricted;
      case PermissionStatus.limited:
        return PermissionResult.granted; // Treat limited as granted for iOS
      case PermissionStatus.provisional:
        return PermissionResult.granted; // Treat provisional as granted for iOS
    }
  }

  String getPermissionMessage(PermissionResult result) {
    switch (result) {
      case PermissionResult.granted:
        return 'Location permission granted';
      case PermissionResult.denied:
        return 'Location permission is required for this app to work properly. Please grant location access.';
      case PermissionResult.permanentlyDenied:
        return 'Location permission has been permanently denied. Please enable it in app settings.';
      case PermissionResult.restricted:
        return 'Location access is restricted on this device.';
    }
  }
}