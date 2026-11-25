import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/info_note.dart';
import '../widgets/primary_button.dart';

/// Halaman yang terbuka dari tautan reset di email: pengguna membuat kata
/// sandi baru memakai sesi pemulihan yang dibuat Supabase.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  bool _done = false;
  bool _linkInvalid = false;

  @override
  void initState() {
    super.initState();
    _linkInvalid = !context.read<AuthRepository>().hasRecoverySession;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await context
          .read<AuthRepository>()
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      // Akhiri sesi pemulihan agar pengguna masuk dengan kata sandi baru.
      context.read<AuthBloc>().add(const AuthLogoutRequested());
      setState(() {
        _saving = false;
        _done = true;
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Gagal menyimpan kata sandi baru. Coba lagi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Kembali ke halaman masuk',
                    onPressed:
                        _saving ? null : () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back_rounded),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const BrandLogo(size: 40),
              ],
            ),
            const SizedBox(height: 20),
            if (_linkInvalid)
              _buildInvalidLink(context)
            else if (_done)
              _buildDone(context)
            else
              _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buat kata sandi baru',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan kata sandi baru untuk akun Anda, lalu masuk kembali.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        AuthTextField(
          label: 'Kata sandi baru',
          hint: 'Minimal 8 karakter',
          controller: _passwordController,
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          validator: Validators.newPassword,
          enabled: !_saving,
        ),
        const SizedBox(height: 20),
        AuthTextField(
          label: 'Konfirmasi kata sandi baru',
          hint: 'Ulangi kata sandi baru',
          controller: _confirmController,
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          validator: (value) =>
              Validators.confirmPassword(value, _passwordController.text),
          onFieldSubmitted: (_) => _submit(),
          enabled: !_saving,
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Simpan kata sandi baru',
          isLoading: _saving,
          onPressed: _submit,
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _saving ? null : () => context.go(AppRoutes.login),
            child: Text(
              'Kembali ke Masuk',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const InfoNote(
          icon: Icons.shield_outlined,
          text: 'Setelah kata sandi diperbarui, masuk kembali dengan kata '
              'sandi baru Anda.',
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.chipFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kata sandi diperbarui',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kata sandi baru Anda sudah tersimpan. Silakan masuk kembali.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Masuk sekarang',
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }

  Widget _buildInvalidLink(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.chipFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.link_off_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tautan tidak valid',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tautan reset sudah kedaluwarsa atau sudah dipakai. Minta tautan '
          'baru, lalu buka dari email terbaru.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Minta tautan baru',
          onPressed: () => context.go(AppRoutes.forgotPassword),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => context.go(AppRoutes.login),
            child: Text(
              'Kembali ke Masuk',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
