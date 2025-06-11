import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionService _permissionService = PermissionService.instance;
  bool _isRequesting = false;
  PermissionResult? _currentStatus;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final status = await _permissionService.checkLocationPermission();
    setState(() {
      _currentStatus = status;
    });

    if (status == PermissionResult.granted) {
      _navigateToHome();
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isRequesting = true;
    });

    final result = await _permissionService.requestLocationPermission();
    
    setState(() {
      _isRequesting = false;
      _currentStatus = result;
    });

    if (result == PermissionResult.granted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _openSettings() async {
    await _permissionService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Location Permission Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Destination Alarm needs location access to:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Monitor your proximity to destinations'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Set destinations using your current location'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Send notifications when you reach destinations'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_currentStatus != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _currentStatus == PermissionResult.granted
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentStatus == PermissionResult.granted
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _currentStatus == PermissionResult.granted
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _currentStatus == PermissionResult.granted
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _permissionService.getPermissionMessage(_currentStatus!),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRequesting 
                      ? null 
                      : (_currentStatus == PermissionResult.permanentlyDenied
                          ? _openSettings
                          : _requestPermission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentStatus == PermissionResult.permanentlyDenied
                              ? 'Open App Settings'
                              : 'Grant Location Permission',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_currentStatus == PermissionResult.granted)
                TextButton(
                  onPressed: _navigateToHome,
                  child: const Text('Continue to App'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}