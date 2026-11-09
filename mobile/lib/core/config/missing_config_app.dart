import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ditampilkan bila SUPABASE_URL / SUPABASE_ANON_KEY belum diberikan,
/// agar penyebabnya jelas (bukan layar kosong atau crash).
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.settings_suggest_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Konfigurasi Supabase belum diisi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Salin env.example.json menjadi env.json, isi SUPABASE_URL '
                  'dan SUPABASE_ANON_KEY dari dashboard Supabase '
                  '(Project Settings > API), lalu jalankan ulang:',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.chipFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SelectableText(
                    'flutter run --dart-define-from-file=env.json',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
