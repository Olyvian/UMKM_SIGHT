import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Kerangka halaman autentikasi: area aman, scroll, dan lebar maksimum
/// agar tetap rapi di tablet.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
