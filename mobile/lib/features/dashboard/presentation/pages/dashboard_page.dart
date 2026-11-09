import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/brand_logo.dart';

/// Placeholder Dashboard (ringkasan stok dan prediksi). Diganti pada iterasi berikutnya.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const BrandLogo(size: 36),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, ${user?.name ?? 'Pemilik Toko'}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.store?.storeName ?? '',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Dasbor stok dan prediksi kebutuhan akan tampil di sini.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
