import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ReservationCard extends StatelessWidget {
  final String bloodGroup;
  final String hospitalName;
  final String status;
  final VoidCallback? onTap;

  const ReservationCard({
    super.key,
    required this.bloodGroup,
    required this.hospitalName,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [

              CircleAvatar(
                radius: 26,

                backgroundColor: AppColors.primary.withValues(alpha: 0.12),

                child: const Icon(
                  Icons.bloodtype,
                  color: AppColors.primary,
                ),
              ),


              const SizedBox(width: 16),


              Expanded(
                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      "$bloodGroup Blood Reservation",

                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),


                    const SizedBox(height: 6),


                    Text(
                      hospitalName,

                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),


                    const SizedBox(height: 4),


                    Text(
                      status,

                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),

                  ],
                ),
              ),


              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
              ),

            ],
          ),
        ),
      ),
    );
  }
}