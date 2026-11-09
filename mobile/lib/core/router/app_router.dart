import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
}

/// Router aplikasi. Perpindahan halaman mengikuti status [AuthBloc]:
///
/// - Saat dibuka, Splash memeriksa sesi tersimpan (status `unknown`).
/// - Belum login: hanya Login & Register yang boleh dibuka; halaman lain
///   (termasuk yang ditambahkan nanti) otomatis dialihkan ke Login.
/// - Sudah login (sesi masih tersimpan): langsung ke Dashboard; Login,
///   Register, dan Splash tidak dapat dibuka lagi.
class AppRouter {
  AppRouter(this._authBloc) {
    _refresh = _GoRouterRefreshStream(_authBloc.stream);
    router = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _refresh,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardPage(),
        ),
      ],
    );
  }

  final AuthBloc _authBloc;
  late final _GoRouterRefreshStream _refresh;
  late final GoRouter router;

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    const publicRoutes = {AppRoutes.login, AppRoutes.register};

    switch (_authBloc.state.status) {
      case AuthStatus.unknown:
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      case AuthStatus.authenticated:
        final isGate = publicRoutes.contains(location) ||
            location == AppRoutes.splash;
        return isGate ? AppRoutes.dashboard : null;
      case AuthStatus.unauthenticated:
        // Default-deny: selain Login/Register, semua halaman wajib login.
        return publicRoutes.contains(location) ? null : AppRoutes.login;
    }
  }

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
