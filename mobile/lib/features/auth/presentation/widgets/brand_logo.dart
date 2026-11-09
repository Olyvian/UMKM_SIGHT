import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 52});

  /// Sisi kotak ikon; ukuran teks mengikuti.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
        SizedBox(width: size * 0.25),
        Text(
          'UMKM Sight',
          style: TextStyle(
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
