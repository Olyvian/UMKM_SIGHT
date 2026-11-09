import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Kapsul kecil berisi ikon dan teks, mis. catatan keamanan data.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.chipFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
