import 'package:flutter/material.dart';

const _seasons = [
  ('summer', 'Лето', '☀'),
  ('autumn', 'Осень', '🍂'),
  ('winter', 'Зима', '❄'),
  ('spring', 'Весна', '🌸'),
];

class SeasonSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const SeasonSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _seasons.map((s) {
        final isSelected = s.$1 == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _SeasonChip(
              value: s.$1,
              label: s.$2,
              emoji: s.$3,
              isSelected: isSelected,
              onTap: () => onChanged(s.$1),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeasonChip({
    required this.value,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C1A0E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFC8A97E) : const Color(0xFFD4C5B0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFC8A97E).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFFC8A97E) : const Color(0xFF7A6152),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
