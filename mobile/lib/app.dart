import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

class UmkmSightApp extends StatefulWidget {
  const UmkmSightApp({super.key});

  @override
  State<UmkmSightApp> createState() => _UmkmSightAppState();
}

class _UmkmSightAppState extends State<UmkmSightApp> {
  late final AppRouter _appRouter = AppRouter(context.read<AuthBloc>());

  @override
  void dispose() {
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
