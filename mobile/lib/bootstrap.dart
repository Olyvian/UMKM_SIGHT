import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SignOutScope;

import 'app.dart';
import 'core/config/missing_config_app.dart';
import 'core/config/supabase_config.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/products/data/repositories/product_repository.dart';

/// Inisialisasi bersama untuk semua entry point.
///
/// [resetSession] = true menghapus sesi lokal lebih dulu sehingga aplikasi
/// selalu mulai dari keadaan belum login (dipakai main_login_preview.dart).
Future<void> bootstrap({bool resetSession = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (!SupabaseConfig.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  final startAtPasswordReset = await _recoverPasswordResetLink();

  final prefs = await SharedPreferences.getInstance();
  final sessionStorage = SessionStorage(prefs);

  if (resetSession) {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    await sessionStorage.clear();
  }

  final authRepository = AuthRepository(
    client: Supabase.instance.client,
    sessionStorage: sessionStorage,
  );
  final productRepository = ProductRepository(
    client: Supabase.instance.client,
  );

  runApp(
    RepositoryProvider.value(
      value: productRepository,
      child: RepositoryProvider.value(
        value: authRepository,
        child: BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepository)
            ..add(const AuthSessionChecked()),
          child: UmkmSightApp(startAtPasswordReset: startAtPasswordReset),
        ),
      ),
    ),
  );
}

/// Mendeteksi tautan reset kata sandi pada peluncuran aplikasi (cold start)
/// dan menunggu sesi pemulihan siap sebelum UI dibuka.
Future<bool> _recoverPasswordResetLink() async {
  if (kIsWeb) return false;

  final Uri? link;
  try {
    link = await AppLinks().getInitialLink();
  } catch (_) {
    return false;
  }
  if (link == null || !_isPasswordRecoveryLink(link)) return false;

  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    try {
      await auth.onAuthStateChange
          .firstWhere((state) => state.session != null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Tautan kedaluwarsa/terpakai: halaman reset menampilkan pesannya.
    }
  }
  return true;
}

bool _isPasswordRecoveryLink(Uri uri) {
  final fragment = Uri.splitQueryString(uri.fragment);
  String? param(String key) => uri.queryParameters[key] ?? fragment[key];

  final type = param('type');
  if (type != null) return type == 'recovery';
  return param('code') != null || param('access_token') != null;
}
