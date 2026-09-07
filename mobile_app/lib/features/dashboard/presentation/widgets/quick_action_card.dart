import 'package:flutter/material.dart';

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius:
            BorderRadius.circular(22),

        onTap: onTap,

        child: Ink(
          padding:
              const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: Theme.of(context)
                .cardColor,

            borderRadius:
                BorderRadius.circular(22),

            border: Border.all(
              color: color.withAlpha(28),
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width: 50,
                height: 50,

                decoration: BoxDecoration(
                  color: color.withAlpha(20),

                  borderRadius:
                      BorderRadius.circular(16),
                ),

                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w700,
                          ),
                    ),
                  ),

                  Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 13,
                    color:
                        Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

