import 'package:flutter/material.dart';

/// A widget that displays tutorial content with title and description.
class TutorialContent extends StatelessWidget {
  /// Creates a tutorial content widget.
  const TutorialContent({
    required this.title,
    required this.description,
    super.key,
  });

  /// The title text to display.
  final String title;

  /// The description text to display.
  final String description;

  @override
  Widget build(BuildContext context) {
    // Colours come from the theme; hardcoded white-on-black rendered as
    // white-on-white under a dark theme.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
