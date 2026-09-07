import 'package:flutter/foundation.dart';

/// Donor-specific information stored in public.donor_profiles.
///
/// The parent donor identity lives in public.donors.
/// This model represents the donor_profiles portion of that relationship.
@immutable
class DonorProfileModel {
  static const Object _notProvided = Object();

  final String? id;

  /// Authenticated user's ID.
  final String userId;

  /// Date-only database field.
  final DateTime? dateOfBirth;

  final double? weight;

  /// Date-only database field.
  final DateTime? lastDonationDate;

  /// available / unavailable
  final String availabilityStatus;

  /// pending / eligible / ineligible
  final String eligibilityStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const DonorProfileModel({
    this.id,
    required this.userId,
    this.dateOfBirth,
    this.weight,
    this.lastDonationDate,
    this.availabilityStatus = 'available',
    this.eligibilityStatus = 'pending',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory DonorProfileModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawUserId = json['user_id']?.toString().trim();

    return DonorProfileModel(
      id: _normalizeNullableString(json['id']),
      userId: rawUserId ?? '',
      dateOfBirth: _parseDate(
        json['date_of_birth'],
        dateOnly: true,
      ),
      weight: _parseDouble(
        json['weight'],
      ),
      lastDonationDate: _parseDate(
        json['last_donation_date'],
        dateOnly: true,
      ),
      availabilityStatus: _normalizeAvailabilityStatus(
        json['availability_status'],
      ),
      eligibilityStatus: _normalizeEligibilityStatus(
        json['eligibility_status'],
      ),
      createdAt: _parseDate(
        json['created_at'],
      ),
      updatedAt: _parseDate(
        json['updated_at'],
      ),
      deletedAt: _parseDate(
        json['deleted_at'],
      ),
    );
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  /// Parses PostgreSQL DATE values without introducing timezone shifts.
  ///
  /// A value such as "1998-05-20" represents a calendar date, not a
  /// moment in UTC. It is therefore reconstructed as a local DateTime.
  ///
  /// Timestamp fields such as created_at/updated_at continue to use
  /// DateTime.tryParse normally.
  static DateTime? _parseDate(
    dynamic value, {
    bool dateOnly = false,
  }) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      if (!dateOnly) {
        return value;
      }

      return DateTime(
        value.year,
        value.month,
        value.day,
      );
    }

    final normalized = value.toString().trim();

    if (normalized.isEmpty) {
      return null;
    }

    if (dateOnly) {
      final match = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})',
      ).firstMatch(normalized);

      if (match != null) {
        final year = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final day = int.tryParse(match.group(3)!);

        if (year != null && month != null && day != null) {
          return DateTime(
            year,
            month,
            day,
          );
        }
      }
    }

    return DateTime.tryParse(normalized);
  }

  // ============================================================
  // DOUBLE PARSER
  // ============================================================

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    final normalized = value.toString().trim();

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  // ============================================================
  // STRING NORMALIZATION
  // ============================================================

  static String? _normalizeNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();

    return normalized.isEmpty ? null : normalized;
  }

  // ============================================================
  // AVAILABILITY NORMALIZATION
  // ============================================================

  static String _normalizeAvailabilityStatus(
    dynamic value,
  ) {
    final normalized = value?.toString().trim().toLowerCase();

    if (normalized == 'unavailable') {
      return 'unavailable';
    }

    return 'available';
  }

  // ============================================================
  // ELIGIBILITY NORMALIZATION
  // ============================================================

  static String _normalizeEligibilityStatus(
    dynamic value,
  ) {
    final normalized = value?.toString().trim().toLowerCase();

    switch (normalized) {
      case 'eligible':
        return 'eligible';

      case 'ineligible':
      case 'not_eligible':
        return 'ineligible';

      case 'pending':
      default:
        return 'pending';
    }
  }

  // ============================================================
  // DATE FORMATTER
  // ============================================================

  /// Formats a calendar date for PostgreSQL DATE columns.
  ///
  /// Deliberately does not use toUtc(), because DATE values should not
  /// move backward/forward depending on the user's timezone.
  static String _formatDateOnly(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date_of_birth': dateOfBirth == null
          ? null
          : _formatDateOnly(dateOfBirth!),
      'weight': weight,
      'last_donation_date': lastDonationDate == null
          ? null
          : _formatDateOnly(lastDonationDate!),
      'availability_status':
          availabilityStatus.trim().toLowerCase(),
      'eligibility_status':
          eligibilityStatus.trim().toLowerCase(),
      'created_at':
          createdAt?.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String(),
      'deleted_at':
          deletedAt?.toIso8601String(),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  DonorProfileModel copyWith({
    String? id,
    String? userId,
    DateTime? dateOfBirth,
    double? weight,
    Object? lastDonationDate = _notProvided,
    String? availabilityStatus,
    String? eligibilityStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _notProvided,
  }) {
    return DonorProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weight: weight ?? this.weight,
      lastDonationDate:
          lastDonationDate == _notProvided
              ? this.lastDonationDate
              : lastDonationDate as DateTime?,
      availabilityStatus:
          availabilityStatus?.trim().toLowerCase() ??
              this.availabilityStatus,
      eligibilityStatus:
          eligibilityStatus?.trim().toLowerCase() ??
              this.eligibilityStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          deletedAt == _notProvided
              ? this.deletedAt
              : deletedAt as DateTime?,
    );
  }

  // ============================================================
  // STRING
  // ============================================================

  @override
  String toString() {
    return 'DonorProfileModel('
        'id: $id, '
        'userId: $userId, '
        'dateOfBirth: $dateOfBirth, '
        'weight: $weight, '
        'lastDonationDate: $lastDonationDate, '
        'availabilityStatus: $availabilityStatus, '
        'eligibilityStatus: $eligibilityStatus, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt, '
        'deletedAt: $deletedAt'
        ')';
  }

  // ============================================================
  // EQUALITY
  // ============================================================

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DonorProfileModel &&
            other.id == id &&
            other.userId == userId &&
            other.dateOfBirth == dateOfBirth &&
            other.weight == weight &&
            other.lastDonationDate == lastDonationDate &&
            other.availabilityStatus ==
                availabilityStatus &&
            other.eligibilityStatus ==
                eligibilityStatus &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.deletedAt == deletedAt);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      dateOfBirth,
      weight,
      lastDonationDate,
      availabilityStatus,
      eligibilityStatus,
      createdAt,
      updatedAt,
      deletedAt,
    );
  }
}
