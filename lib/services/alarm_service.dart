import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/destination.dart';

class AlarmService {
  static AlarmService? _instance;
  AlarmService._internal();
  
  static AlarmService get instance {
    _instance ??= AlarmService._internal();
    return _instance!;
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alarmTimer;
  bool _isAlarmActive = false;
  BuildContext? _overlayContext;
  OverlayEntry? _overlayEntry;

  Future<void> triggerDestinationAlarm(Destination destination) async {
    if (_isAlarmActive) {
      return; // Don't trigger multiple alarms
    }

    _isAlarmActive = true;
    
    // Start alarm sound
    await _playAlarmSound();
    
    // Start vibration
    await _startVibration();
    
    // Show fullscreen alarm overlay
    _showAlarmOverlay(destination);
    
    // Auto-dismiss after 30 seconds if not manually dismissed
    _alarmTimer = Timer(const Duration(seconds: 30), () {
      dismissAlarm();
    });
  }

  Future<void> _playAlarmSound() async {
    try {
      // Set up looping alarm sound
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      
      // Try to play a system alarm sound
      // This will use platform-specific alarm sounds
      await _audioPlayer.play(DeviceFileSource('/system/media/audio/alarms/Alarm_Classic.ogg'));
    } catch (e) {
      try {
        // Fallback to notification sound with loop
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(DeviceFileSource('/system/media/audio/notifications/notification_1.ogg'));
      } catch (e2) {
        // Final fallback to system sound
        _playSystemAlertLoop();
      }
    }
  }

  void _playSystemAlertLoop() {
    // Play system alert sound repeatedly
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isAlarmActive) {
        timer.cancel();
        return;
      }
      HapticFeedback.vibrate();
    });
  }

  Future<void> _startVibration() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Create an alarm-like vibration pattern
        // Pattern: [wait, vibrate, wait, vibrate] in milliseconds
        const pattern = [0, 500, 200, 500, 200, 500, 200, 500];
        
        bool? hasCustomVibrations = await Vibration.hasCustomVibrationsSupport();
        if (hasCustomVibrations == true) {
          Vibration.vibrate(pattern: pattern, repeat: 0);
        } else {
          Vibration.vibrate(duration: 2000);
        }
      }
    } catch (e) {
      // Vibration not supported, continue without it
    }
  }

  void _showAlarmOverlay(Destination destination) {
    final context = _getOverlayContext();
    if (context == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => AlarmOverlay(
        destination: destination,
        onDismiss: dismissAlarm,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  BuildContext? _getOverlayContext() {
    // This would need to be set by the main app
    return _overlayContext;
  }

  void setOverlayContext(BuildContext context) {
    _overlayContext = context;
  }

  Future<void> dismissAlarm() async {
    if (!_isAlarmActive) return;

    _isAlarmActive = false;
    
    // Stop alarm timer
    _alarmTimer?.cancel();
    _alarmTimer = null;
    
    // Stop sound
    await _audioPlayer.stop();
    
    // Stop vibration
    Vibration.cancel();
    
    // Remove overlay
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void dispose() {
    _audioPlayer.dispose();
    dismissAlarm();
  }
}

class AlarmOverlay extends StatefulWidget {
  final Destination destination;
  final VoidCallback onDismiss;

  const AlarmOverlay({
    super.key,
    required this.destination,
    required this.onDismiss,
  });

  @override
  State<AlarmOverlay> createState() => _AlarmOverlayState();
}

class _AlarmOverlayState extends State<AlarmOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _shakeAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _pulseController.repeat(reverse: true);
    _shakeController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.withValues(alpha: 0.95),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: const Icon(
                            Icons.warning,
                            size: 120,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text(
                'DESTINATION REACHED!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.destination.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are within ${widget.destination.radiusInMeters.toInt()}m of your destination',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'STOP ALARM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tap to dismiss alarm',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}