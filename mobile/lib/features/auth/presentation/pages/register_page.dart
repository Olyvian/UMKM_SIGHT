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
import '../widgets/password_strength_bar.dart';
import '../widgets/primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _storeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _strength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthRegisterRequested(
            name: _nameController.text.trim(),
            storeName: _storeController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
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
              // Baris atas: tombol kembali + logo di tengah.
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Kembali ke halaman masuk',
                      onPressed: isSubmitting
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.chipFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Akses Cepat & Prediksi Akurat',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Buat Akun UMKM Sight',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mulai pantau risiko stok habis dengan prediksi cerdas.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const _FeatureHighlight(),
              const SizedBox(height: 28),
              AuthTextField(
                label: 'Nama lengkap',
                hint: 'Budi Santoso',
                controller: _nameController,
                suffixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => Validators.name(v, 'Nama lengkap'),
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Nama toko',
                hint: 'Toko Berkah Jaya',
                controller: _storeController,
                suffixIcon: Icons.storefront_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.name(v, 'Nama toko'),
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Email',
                hint: 'budi@tokoberkah.com',
                controller: _emailController,
                suffixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: Validators.email,
                enabled: !isSubmitting,
                trailingLabel: Text(
                  'Wajib aktif',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                helper: 'Pastikan email aktif untuk pemulihan akun.',
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Kata sandi',
                hint: 'Minimal 8 karakter',
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
                onChanged: (value) {
                  setState(() => _strength = Validators.passwordStrength(value));
                },
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 10),
              PasswordStrengthBar(level: _strength),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Konfirmasi kata sandi',
                hint: 'Masukkan ulang kata sandi',
                controller: _confirmController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    Validators.confirmPassword(v, _passwordController.text),
                onFieldSubmitted: (_) => _submit(),
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Daftar',
                isLoading: isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Sudah punya akun? ',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: isSubmitting
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
                icon: Icons.lock_outline_rounded,
                text: 'Data bisnis Anda dienkripsi dan terlindungi aman.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  const _FeatureHighlight();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.chipFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventaris Otomatis',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Notifikasi stok menipis sebelum penjualan terhenti.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
