import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umkm_sight/core/storage/session_storage.dart';
import 'package:umkm_sight/features/auth/data/repositories/auth_repository.dart';
import 'package:umkm_sight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:umkm_sight/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('halaman login menampilkan form masuk', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sessionStorage = SessionStorage(prefs);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final authRepository = AuthRepository(
      client: client,
      sessionStorage: sessionStorage,
    );

    await tester.pumpWidget(
      RepositoryProvider.value(
        value: authRepository,
        child: BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepository),
          child: const MaterialApp(home: LoginPage()),
        ),
      ),
    );

    expect(find.text('Selamat datang kembali'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('Daftar'), findsOneWidget);
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
  });
}
