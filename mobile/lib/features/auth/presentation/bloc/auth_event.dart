part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dikirim saat aplikasi dibuka untuk memeriksa token sesi.
final class AuthSessionChecked extends AuthEvent {
  const AuthSessionChecked();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.storeName,
    required this.email,
    required this.password,
  });

  final String name;
  final String storeName;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, storeName, email, password];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
