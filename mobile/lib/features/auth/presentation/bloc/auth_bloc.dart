import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState()) {
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;

  static const _unexpectedError = 'Terjadi kesalahan tak terduga. Coba lagi.';

  Future<void> _onSessionChecked(
    AuthSessionChecked event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _authRepository.restoreSession();
      if (user != null) {
        emit(AuthState(status: AuthStatus.authenticated, user: user));
        return;
      }
    } catch (_) {
      // Sesi tidak dapat dipulihkan: perlakukan sebagai belum login.
    }
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on AuthFailure catch (e) {
      emit(AuthState(status: AuthStatus.unauthenticated, errorMessage: e.message));
    } catch (_) {
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: _unexpectedError,
        ),
      );
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final user = await _authRepository.register(
        name: event.name,
        storeName: event.storeName,
        email: event.email,
        password: event.password,
      );
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } on AuthFailure catch (e) {
      emit(AuthState(status: AuthStatus.unauthenticated, errorMessage: e.message));
    } catch (_) {
      emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: _unexpectedError,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
