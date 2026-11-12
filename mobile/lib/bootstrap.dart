import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SignOutScope;

import 'app.dart';
import 'core/config/missing_config_app.dart';
import 'core/config/supabase_config.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

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
    anonKey: SupabaseConfig.anonKey,
  );

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

  runApp(
    RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        create: (_) => AuthBloc(authRepository: authRepository)
          ..add(const AuthSessionChecked()),
        child: const UmkmSightApp(),
      ),
    ),
  );
}
