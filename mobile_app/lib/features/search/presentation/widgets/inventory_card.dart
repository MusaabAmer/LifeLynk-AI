import 'package:flutter/material.dart';

import '../../data/models/blood_inventory_model.dart';

class InventoryCard extends StatelessWidget {
  final BloodInventoryModel inventory;

  const InventoryCard({
    super.key,
    required this.inventory,
  });

  Color _statusColor() {
    final units = inventory.availableUnits;

    if (units <= 0) {
      return Colors.red;
    }

    if (units < 5) {
      return Colors.orange;
    }

    return Colors.green;
  }

  String _statusText() {
    final units = inventory.availableUnits;

    if (units <= 0) {
      return 'Unavailable';
    }

    if (units < 5) {
      return 'Low stock';
    }

    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            inventory.bloodGroup,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '${inventory.availableUnits} Units',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${inventory.reservedUnits} Reserved',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bloodtype,
                size: 18,
                color: statusColor,
              ),

              const SizedBox(width: 5),

              Text(
                _statusText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}