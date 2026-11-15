import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/info_note.dart';
import '../widgets/primary_button.dart';

/// Halaman "Lupa kata sandi?": pengguna memasukkan email, lalu Supabase
/// mengirim tautan untuk membuat kata sandi baru.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _sending = false;
  bool _sent = false;
  String _sentTo = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _sending = true);

    try {
      await context.read<AuthRepository>().requestPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
        _sentTo = email;
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError('Gagal mengirim tautan reset. Coba lagi.');
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
                    onPressed: _sending
                        ? null
                        : () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back_rounded),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const BrandLogo(size: 40),
              ],
            ),
            const SizedBox(height: 20),
            if (_sent) _buildSent(context) else _buildForm(context),
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
          'Lupa kata sandi?',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan email toko Anda. Kami akan mengirim tautan untuk '
          'membuat kata sandi baru.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        AuthTextField(
          label: 'Email Toko',
          hint: 'nama@tokoberkah.com',
          controller: _emailController,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          ],
          validator: Validators.email,
          onFieldSubmitted: (_) => _submit(),
          enabled: !_sending,
          helper: 'Tautan dikirim ke email yang terdaftar pada akun Anda.',
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Kirim tautan reset',
          isLoading: _sending,
          onPressed: _submit,
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Ingat kata sandi? ',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: _sending
                    ? null
                    : () => context.go(AppRoutes.login),
                child: Text(
                  'Masuk',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const InfoNote(
          icon: Icons.shield_outlined,
          text: 'Demi keamanan, kami tidak menampilkan apakah email terdaftar.',
        ),
      ],
    );
  }

  Widget _buildSent(BuildContext context) {
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
            Icons.mark_email_read_outlined,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Cek email Anda',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Jika $_sentTo terdaftar, kami sudah mengirim tautan untuk membuat '
          'kata sandi baru. Buka tautan tersebut, lalu masuk dengan kata '
          'sandi yang baru.',
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          label: 'Kembali ke Masuk',
          onPressed: () => context.go(AppRoutes.login),
        ),
        const SizedBox(height: 24),
        const InfoNote(
          icon: Icons.schedule_rounded,
          text: 'Tidak menerima email? Tunggu beberapa saat sebelum mencoba lagi.',
        ),
      ],
    );
  }
}
