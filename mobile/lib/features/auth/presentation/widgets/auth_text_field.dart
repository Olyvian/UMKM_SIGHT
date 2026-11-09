import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Kolom input bergaya desain UMKM Sight: label di atas, isian putih
/// membulat, ikon di kiri atau kanan, dan tombol lihat/sembunyi sandi.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.trailingLabel,
    this.helper,
    this.inputFormatters,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isPassword;

  /// Teks di sisi kanan label, mis. "Wajib aktif" atau tautan "Lupa kata sandi?".
  final Widget? trailingLabel;

  /// Petunjuk kecil di bawah kolom (dengan ikon info).
  final String? helper;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure = widget.isPassword;

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget? suffix;
    if (widget.isPassword) {
      suffix = IconButton(
        tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.textSecondary,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    } else if (widget.suffixIcon != null) {
      suffix = Icon(widget.suffixIcon, color: AppColors.textHint, size: 22);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (widget.trailingLabel != null) widget.trailingLabel!,
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: _obscure,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            inputFormatters: widget.inputFormatters,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle:
                  const TextStyle(fontSize: 16, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, color: AppColors.textSecondary),
              suffixIcon: suffix,
              border: _border(AppColors.fieldBorder),
              enabledBorder: _border(AppColors.fieldBorder),
              disabledBorder: _border(AppColors.fieldBorder),
              focusedBorder: _border(AppColors.primary, width: 1.5),
              errorBorder: _border(AppColors.danger),
              focusedErrorBorder: _border(AppColors.danger, width: 1.5),
              errorStyle: const TextStyle(fontSize: 12.5),
            ),
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.helper!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
