
import 'package:flutter/foundation.dart';

@immutable
class DonationHistoryModel {
  final String id;
  final String donorId;
  final String organizationId;
  final String organizationName;
  final String bloodGroupId;
  final String bloodGroupCode;
  final String bloodGroupName;
  final int unitsDonated;
  final DateTime donationDate;
  final bool verified;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DonationHistoryModel({
    required this.id,
    required this.donorId,
    required this.organizationId,
    required this.organizationName,
    required this.bloodGroupId,
    required this.bloodGroupCode,
    required this.bloodGroupName,
    required this.unitsDonated,
    required this.donationDate,
    required this.verified,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DonationHistoryModel.fromJson(Map<String, dynamic> json) {
    final organization = _nestedObject(json['organizations']);
    final bloodGroup = _nestedObject(json['blood_groups']);

    return DonationHistoryModel(
      id: _requiredString(
        json['id'],
        fieldName: 'id',
      ),
      donorId: _requiredString(
        json['donor_id'],
        fieldName: 'donor_id',
      ),
      organizationId: _requiredString(
        json['organization_id'],
        fieldName: 'organization_id',
      ),
      organizationName:
          _stringValue(organization?['name']) ??
          'Unknown organization',
      bloodGroupId: _requiredString(
        json['blood_group_id'],
        fieldName: 'blood_group_id',
      ),
      bloodGroupCode:
          _stringValue(bloodGroup?['code']) ?? '',
      bloodGroupName:
          _stringValue(bloodGroup?['name']) ?? '',
      unitsDonated: _intValue(json['units_donated']),
      donationDate: _requiredDate(
        json['donation_date'],
        fieldName: 'donation_date',
      ),
      verified: _boolValue(json['verified']),
      notes: _stringValue(json['notes']),
      createdAt: _dateValue(json['created_at']),
      updatedAt: _dateValue(json['updated_at']),
    );
  }

  /// Handles Supabase nested relationships returned as either:
  /// - List containing the related object
  /// - null
  static Map<String, dynamic>? _nestedObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;

      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return null;
  }

  static String _requiredString(
    dynamic value, {
    required String fieldName,
  }) {
    final result = value?.toString().trim();

    if (result == null || result.isEmpty) {
      throw FormatException(
        'Required donation history field "$fieldName" is missing.',
      );
    }

    return result;
  }

  static String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase();

    return normalized == 'true' || normalized == '1';
  }

  static DateTime? _dateValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  static DateTime _requiredDate(
    dynamic value, {
    required String fieldName,
  }) {
    final parsed = _dateValue(value);

    if (parsed == null) {
      throw FormatException(
        'Required donation history field "$fieldName" is missing or invalid.',
      );
    }

    return parsed;
  }

  String get displayBloodGroup {
    if (bloodGroupCode.isNotEmpty) {
      return bloodGroupCode;
    }

    if (bloodGroupName.isNotEmpty) {
      return bloodGroupName;
    }

    return 'Unknown';
  }

  String get displayOrganization {
    if (organizationName.isNotEmpty) {
      return organizationName;
    }

    return 'Unknown organization';
  }

  @override
  String toString() {
    return 'DonationHistoryModel('
        'id: $id, '
        'donorId: $donorId, '
        'organizationName: $organizationName, '
        'unitsDonated: $unitsDonated, '
        'donationDate: $donationDate, '
        'verified: $verified'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DonationHistoryModel &&
        other.id == id &&
        other.donorId == donorId &&
        other.organizationId == organizationId &&
        other.bloodGroupId == bloodGroupId &&
        other.unitsDonated == unitsDonated &&
        other.donationDate == donationDate &&
        other.verified == verified &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      donorId,
      organizationId,
      bloodGroupId,
      unitsDonated,
      donationDate,
      verified,
      notes,
    );
  }
}
