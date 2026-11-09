import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Field putih berujung bulat dengan bayangan halus, sesuai desain.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border([Color color = Colors.transparent]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: 1.4),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        style: GoogleFonts.inter(fontSize: 16, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.hint),
          filled: true,
          fillColor: AppColors.surface,
          prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 24),
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          border: border(),
          enabledBorder: border(),
          disabledBorder: border(),
          focusedBorder: border(AppColors.primary),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error),
          errorStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
        ),
      ),
    );
  }
}