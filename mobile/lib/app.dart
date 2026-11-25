import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, Supabase;

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart' show AuthBloc;

class UmkmSightApp extends StatefulWidget {
  const UmkmSightApp({super.key, this.startAtPasswordReset = false});

  /// True bila aplikasi dibuka dari tautan reset kata sandi di email.
  final bool startAtPasswordReset;

  @override
  State<UmkmSightApp> createState() => _UmkmSightAppState();
}

class _UmkmSightAppState extends State<UmkmSightApp> {
  late final AppRouter _appRouter = AppRouter(
    context.read<AuthBloc>(),
    initialLocation: widget.startAtPasswordReset
        ? AppRoutes.resetPassword
        : AppRoutes.splash,
  );
  late final StreamSubscription<dynamic> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Tautan reset yang dibuka saat aplikasi sudah berjalan.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (!mounted) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _appRouter.router.go(AppRoutes.resetPassword);
        }
      },
      // Tautan kedaluwarsa/terpakai ditangani halaman reset.
      onError: (_, __) {},
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _appRouter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UMKM Sight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _appRouter.router,
    );
  }
}
