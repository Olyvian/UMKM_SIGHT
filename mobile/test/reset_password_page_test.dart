import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umkm_sight/core/storage/session_storage.dart';
import 'package:umkm_sight/features/auth/data/repositories/auth_repository.dart';
import 'package:umkm_sight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:umkm_sight/features/auth/presentation/pages/reset_password_page.dart';

void main() {
  testWidgets('halaman reset menolak tautan tanpa sesi pemulihan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepository = AuthRepository(
      client: SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      sessionStorage: SessionStorage(prefs),
    );

    await tester.pumpWidget(
      RepositoryProvider.value(
        value: authRepository,
        child: BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepository),
          child: const MaterialApp(home: ResetPasswordPage()),
        ),
      ),
    );

    expect(find.text('Tautan tidak valid'), findsOneWidget);
    expect(find.text('Minta tautan baru'), findsOneWidget);
    expect(find.text('Simpan kata sandi baru'), findsNothing);
  });
}
