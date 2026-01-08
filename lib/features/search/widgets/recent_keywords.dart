import 'package:flutter/material.dart';

class RecentKeywords extends StatelessWidget {
  final List<String> keywords;
  final void Function(String keyword) onTap;

  const RecentKeywords({
    super.key,
    required this.keywords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (keywords.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: keywords
            .map(
              (keyword) => ActionChip(
                label: Text(keyword),
                onPressed: () => onTap(keyword),
              ),
            )
            .toList(),
      ),
    );
  }
}




