import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Tiga segmen indikator kekuatan kata sandi. [level] bernilai 0 sampai 3.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.level});

  final int level;

  static const _labels = ['', 'Lemah', 'Cukup', 'Kuat'];

  Color get _activeColor => switch (level) {
        1 => AppColors.danger,
        2 => AppColors.warning,
        _ => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < level ? _activeColor : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (level > 0) ...[
          const SizedBox(height: 6),
          Text(
            'Kekuatan kata sandi: ${_labels[level]}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
          ),
        ],
      ],
    );
  }
}
