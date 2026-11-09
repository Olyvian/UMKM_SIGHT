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
  final apiClient = ApiClient(sessionStorage);
  final authRepository = AuthRepository(
    apiClient: apiClient,
    sessionStorage: sessionStorage,
  );

  runApp(
    RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        create: (_) =>
            AuthBloc(authRepository: authRepository)..add(const AuthSessionChecked()),
        child: const UmkmSightApp(),
      ),
    ),
  );
}
