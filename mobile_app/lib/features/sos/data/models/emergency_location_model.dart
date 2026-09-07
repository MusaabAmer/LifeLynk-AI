import 'package:geolocator/geolocator.dart';

class EmergencyLocationModel {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const EmergencyLocationModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  factory EmergencyLocationModel.fromPosition(
    Position position,
  ) {
    return EmergencyLocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  factory EmergencyLocationModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return EmergencyLocationModel(
      latitude:
          (map['latitude'] as num).toDouble(),
      longitude:
          (map['longitude'] as num).toDouble(),
      accuracy:
          (map['accuracy'] as num?)?.toDouble() ??
              0.0,
      timestamp:
          DateTime.parse(
        map['timestamp'].toString(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp':
          timestamp.toUtc().toIso8601String(),
    };
  }
}