import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/alarm_service.dart';
import 'screens/home_screen.dart';
import 'screens/permission_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService.instance.initialize();
  
  runApp(const DestinationAlarmApp());
}

class DestinationAlarmApp extends StatefulWidget {
  const DestinationAlarmApp({super.key});

  @override
  State<DestinationAlarmApp> createState() => _DestinationAlarmAppState();
}

class _DestinationAlarmAppState extends State<DestinationAlarmApp> {
  bool _isCheckingPermissions = true;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    final permissionService = PermissionService.instance;
    final hasPermission = await permissionService.isLocationPermissionGranted();
    
    setState(() {
      _hasLocationPermission = hasPermission;
      _isCheckingPermissions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Destination Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _isCheckingPermissions
          ? const SplashScreen()
          : _hasLocationPermission
              ? const HomeScreen()
              : const PermissionScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/permissions': (context) => const PermissionScreen(),
      },
      builder: (context, child) {
        // Set the overlay context for the alarm service
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AlarmService.instance.setOverlayContext(context);
        });
        return child!;
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Destination Alarm',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
