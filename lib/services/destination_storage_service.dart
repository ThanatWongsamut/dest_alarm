import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/destination.dart';

class DestinationStorageService {
  static const String _destinationsKey = 'destinations';

  Future<List<Destination>> getDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationsJson = prefs.getStringList(_destinationsKey) ?? [];
    
    return destinationsJson
        .map((json) => Destination.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> saveDestination(Destination destination) async {
    final destinations = await getDestinations();
    final existingIndex = destinations.indexWhere((d) => d.id == destination.id);
    
    if (existingIndex != -1) {
      destinations[existingIndex] = destination;
    } else {
      destinations.add(destination);
    }
    
    await _saveDestinations(destinations);
  }

  Future<void> deleteDestination(String id) async {
    final destinations = await getDestinations();
    destinations.removeWhere((d) => d.id == id);
    await _saveDestinations(destinations);
  }

  Future<void> updateDestination(Destination destination) async {
    await saveDestination(destination);
  }

  Future<List<Destination>> getActiveDestinations() async {
    final destinations = await getDestinations();
    return destinations.where((d) => d.isActive).toList();
  }

  Future<void> _saveDestinations(List<Destination> destinations) async {
    final prefs = await SharedPreferences.getInstance();
    final destinationsJson = destinations
        .map((d) => jsonEncode(d.toJson()))
        .toList();
    
    await prefs.setStringList(_destinationsKey, destinationsJson);
  }
}