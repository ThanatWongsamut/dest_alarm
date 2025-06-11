class Destination {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusInMeters;
  final bool isActive;
  final DateTime createdAt;

  Destination({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
    required this.isActive,
    required this.createdAt,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      radiusInMeters: json['radiusInMeters'],
      isActive: json['isActive'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusInMeters': radiusInMeters,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Destination copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusInMeters,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}