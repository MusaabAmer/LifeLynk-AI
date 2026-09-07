class ServiceModel {
  final String name;
  final bool isAvailable;
  final String? value;

  const ServiceModel({
    required this.name,
    required this.isAvailable,
    this.value,
  });

  factory ServiceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ServiceModel(
      name:
          json['name']?.toString() ??
          json['service_name']?.toString() ??
          '',
      isAvailable:
          json['available'] as bool? ??
          json['is_available'] as bool? ??
          false,
      value:
          json['value']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'available': isAvailable,
      'value': value,
    };
  }
}