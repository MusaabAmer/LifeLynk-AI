import 'package:flutter/material.dart';

class RatingCard extends StatelessWidget {
  final double? rating;
  final int? reviewCount;

  const RatingCard({
    super.key,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final reviews = reviewCount ?? 0;

    if (rating == null || reviews == 0) {
      return const SizedBox.shrink();
    }

    final value = rating!.clamp(0.0, 5.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.star,
              color: Colors.amber,
              size: 32,
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '$reviews ${reviews == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}