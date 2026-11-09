// ENTRY POINT SEMENTARA untuk menguji halaman Login.
//
// Jalankan dengan:
//   flutter run -t lib/main_login_preview.dart
//
// Perbedaan dari main.dart:
//  - Sesi lokal dihapus setiap aplikasi dijalankan, sehingga selalu mulai dari
//    keadaan "belum login" dan halaman Masuk selalu tampil.
//  - Selebihnya sama (router, AuthBloc, tema), jadi alur Masuk -> Dashboard ->
//    Keluar, serta tautan ke halaman Daftar, tetap bisa dicoba.
//
// Login memakai data tiruan (mock) secara default: email valid + kata sandi
// apa saja akan berhasil. Untuk backend sungguhan tambahkan
//   --dart-define=USE_MOCK=false
//
// Hapus file ini bila sudah tidak diperlukan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final sessionStorage = SessionStorage(prefs);

  // Selalu mulai dari keadaan belum login.
  await sessionStorage.clear();

  final apiClient = ApiClient(sessionStorage);
  final authRepository = AuthRepository(
    apiClient: apiClient,
    sessionStorage: sessionStorage,
  );

  runApp(
    RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        // Sesi sudah kosong, jadi status menjadi unauthenticated dan router
        // langsung membuka halaman Masuk.
        create: (_) => AuthBloc(authRepository: authRepository)
          ..add(const AuthSessionChecked()),
        child: const UmkmSightApp(),
      ),
    ),
  );
}
