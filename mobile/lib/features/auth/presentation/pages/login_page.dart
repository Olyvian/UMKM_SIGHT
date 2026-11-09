import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/brand_logo.dart';
import '../widgets/info_note.dart';
import '../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  void _showForgotPasswordInfo() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Pemulihan kata sandi segera hadir.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isSubmitting =
        context.select((AuthBloc bloc) => bloc.state.isSubmitting);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      child: AuthScaffold(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const BrandLogo(),
              const SizedBox(height: 48),
              Text(
                'Selamat datang kembali',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masuk untuk mengelola stok dan melihat prediksi kebutuhan toko.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: 'Email Toko',
                hint: 'nama@tokoberkah.com',
                controller: _emailController,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: Validators.email,
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Kata Sandi',
                hint: '••••••••',
                controller: _passwordController,
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.loginPassword,
                onFieldSubmitted: (_) => _submit(),
                enabled: !isSubmitting,
                trailingLabel: GestureDetector(
                  onTap: _showForgotPasswordInfo,
                  child: Text(
                    'Lupa kata sandi?',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Masuk',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: isSubmitting
                          ? null
                          : () => context.go(AppRoutes.register),
                      child: Text(
                        'Daftar',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const InfoNote(
                icon: Icons.verified_user_rounded,
                text: 'Keamanan data inventaris toko terenkripsi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
