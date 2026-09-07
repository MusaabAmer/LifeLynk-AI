import 'package:flutter/material.dart';

import '../../data/models/blood_inventory_model.dart';
import 'inventory_card.dart';

class BloodInventoryGrid extends StatelessWidget {
  final List<BloodInventoryModel> inventory;

  const BloodInventoryGrid({
    super.key,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Inventory',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            if (inventory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No blood inventory available.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: inventory.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (context, index) {
                  return InventoryCard(
                    inventory: inventory[index],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}