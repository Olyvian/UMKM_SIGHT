part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isSubmitting;
  final String? errorMessage;

  /// `errorMessage` sengaja tidak dipertahankan: setiap perubahan state
  /// menghapus pesan error sebelumnya kecuali diisi ulang.
  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, errorMessage];
}
