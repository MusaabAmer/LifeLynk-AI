import 'package:flutter/material.dart';

import 'ai_suggestion_chip.dart';

class AiSuggestions extends StatelessWidget {
  final ValueChanged<String> onSuggestionSelected;

  const AiSuggestions({
    super.key,
    required this.onSuggestionSelected,
  });

  static const List<_AiSuggestion> _suggestions = [
    _AiSuggestion(
      label: 'Blood compatibility',
      prompt: 'Explain blood group compatibility',
      icon: Icons.bloodtype_outlined,
    ),
    _AiSuggestion(
      label: 'Donation eligibility',
      prompt: 'What are the requirements for donating blood?',
      icon: Icons.volunteer_activism_outlined,
    ),
    _AiSuggestion(
      label: 'Emergency guidance',
      prompt: 'What should I do if someone urgently needs blood?',
      icon: Icons.emergency_outlined,
    ),
    _AiSuggestion(
      label: 'Find blood',
      prompt: 'How can I find available blood near me?',
      icon: Icons.location_on_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can I help?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((suggestion) {
            return AiSuggestionChip(
              label: suggestion.label,
              icon: suggestion.icon,
              onTap: () {
                onSuggestionSelected(
                  suggestion.prompt,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AiSuggestion {
  final String label;
  final String prompt;
  final IconData icon;

  const _AiSuggestion({
    required this.label,
    required this.prompt,
    required this.icon,
  });
}