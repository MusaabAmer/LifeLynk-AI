import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../donor/models/donor_profile_model.dart';

class DonorProfileCard extends StatelessWidget {
  final DonorProfileModel? donor;
  final VoidCallback onTap;

  const DonorProfileCard({
    super.key,
    required this.donor,
    required this.onTap,
  });

  bool get isDonor => donor != null;

  @override
  Widget build(BuildContext context) {
    if (!isDonor) {
      return _buildBecomeDonorCard(context);
    }

    return _buildDonorCard(context);
  }

  // ============================================================
  // BECOME A DONOR
  // ============================================================

  Widget _buildBecomeDonorCard(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.bloodtype_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become a Donor',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help save lives by donating blood.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DONOR PROFILE
  // ============================================================

  Widget _buildDonorCard(BuildContext context) {
    final donorProfile = donor!;

    final isAvailable =
        donorProfile.availabilityStatus == 'available';

    final isEligible =
        donorProfile.eligibilityStatus == 'eligible';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // Header
              // ------------------------------------------------

              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.bloodtype_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donor Profile',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _StatusDot(
                              color: isAvailable
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isAvailable
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ------------------------------------------------
              // Status
              // ------------------------------------------------

              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.verified_outlined,
                      label: 'Eligibility',
                      value: _formatStatus(
                        donorProfile.eligibilityStatus,
                      ),
                      iconColor: isEligible
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
  child: _InfoItem(
    icon: Icons.monitor_weight_outlined,
    label: 'Weight',
    value: donorProfile.weight != null
        ? '${donorProfile.weight!.toStringAsFixed(0)} kg'
        : 'Not provided',
    iconColor: AppColors.primary,
  ),
),
                ],
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // Last Donation
              // ------------------------------------------------

              _InfoItem(
                icon: Icons.calendar_today_outlined,
                label: 'Last Donation',
                value: donorProfile.lastDonationDate != null
                    ? _formatDate(
                        donorProfile.lastDonationDate!,
                      )
                    : 'No donation recorded',
                iconColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatStatus(String value) {
    if (value.isEmpty) {
      return 'Pending';
    }

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ============================================================
// INFO ITEM
// ============================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS DOT
// ============================================================

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}