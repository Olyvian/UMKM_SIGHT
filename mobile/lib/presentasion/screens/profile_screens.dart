import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_shell.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// ---------- Warna tambahan khusus halaman ini ----------
const _kRed = Color(0xFFB91C1C);
const _kRedBg = Color(0xFFFEE2E2);
const _kBadgeBg = Color(0xFFE0E7FF);
const _kBox = Color(0xFFEFF2FB);
const _kDivider = Color(0x12000000);
const _kSwitchOff = Color(0xFFC7CAD9);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  final letters = parts.take(2).map((e) => e[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

// =====================================================================
class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens> {
  // Data contoh (ganti dengan data dari API / penyimpanan lokal nanti)
  String _name = 'Budi Santoso';
  String _email = 'budi@tokoberkah.com';
  final String _role = 'Owner';

  String _storeName = 'Toko Berkah Jaya';
  String _category = 'Sembako & Kebutuhan Harian';
  String _address = 'Pasar Cipinang Blok B No. 12, Jakarta Timur';

  bool _lowStockAlert = true;
  bool _outOfStockAlert = true;
  bool _weeklyReport = false;
  int _thresholdDays = 3; // kirim peringatan saat estimasi habis <= N hari

  String _passwordInfo = 'Terakhir diperbarui 30 hari lalu';

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editProfile() async {
    final v = await _showFormSheet(
      context,
      title: 'Ubah Profil',
      subtitle: 'Perbarui nama dan email akunmu.',
      fields: [
        _Field('Nama lengkap', initial: _name),
        _Field('Email', initial: _email, keyboard: TextInputType.emailAddress),
      ],
      validate: (v) {
        if (v[0].isEmpty) return 'Nama tidak boleh kosong';
        if (!v[1].contains('@') || !v[1].contains('.')) {
          return 'Format email tidak valid';
        }
        return null;
      },
    );
    if (v == null || !mounted) return;
    setState(() {
      _name = v[0];
      _email = v[1];
    });
    _toast('Profil diperbarui');
  }

  Future<void> _editStore() async {
    final v = await _showFormSheet(
      context,
      title: 'Ubah Informasi Toko',
      fields: [
        _Field('Nama toko', initial: _storeName),
        _Field('Kategori usaha', initial: _category),
        _Field('Alamat operasional', initial: _address, maxLines: 3),
      ],
      validate: (v) =>
          v.any((e) => e.isEmpty) ? 'Semua kolom wajib diisi' : null,
    );
    if (v == null || !mounted) return;
    setState(() {
      _storeName = v[0];
      _category = v[1];
      _address = v[2];
    });
    _toast('Informasi toko diperbarui');
  }

  Future<void> _changePassword() async {
    final v = await _showFormSheet(
      context,
      title: 'Ubah Kata Sandi',
      subtitle: 'Gunakan minimal 8 karakter.',
      fields: const [
        _Field('Kata sandi saat ini', obscure: true),
        _Field('Kata sandi baru', obscure: true),
        _Field('Konfirmasi kata sandi baru', obscure: true),
      ],
      validate: (v) {
        if (v.any((e) => e.isEmpty)) return 'Semua kolom wajib diisi';
        if (v[1].length < 8) return 'Kata sandi baru minimal 8 karakter';
        if (v[1] != v[2]) return 'Konfirmasi kata sandi tidak cocok';
        return null;
      },
    );
    if (v == null || !mounted) return;
    // TODO: kirim ke API untuk mengganti kata sandi
    setState(() => _passwordInfo = 'Baru saja diperbarui');
    _toast('Kata sandi berhasil diubah');
  }

    Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar dari akun?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Kamu perlu masuk lagi untuk membuka data toko di aplikasi ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar',
                style: TextStyle(color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ProfileBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _ProfileCard(
                    name: _name,
                    email: _email,
                    role: _role,
                    onEdit: _editProfile,
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                      title: 'Informasi Toko',
                      action: 'Ubah',
                      onAction: _editStore),
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 6),
                    child: Column(
                      children: [
                        _InfoTile(
                            icon: Icons.storefront_outlined,
                            label: 'Nama Toko',
                            value: _storeName),
                        const _Divider(),
                        _InfoTile(
                            icon: Icons.category_outlined,
                            label: 'Kategori Usaha',
                            value: _category),
                        const _Divider(),
                        _InfoTile(
                            icon: Icons.location_on_outlined,
                            label: 'Alamat Operasional',
                            value: _address),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Preferensi Notifikasi'),
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 6),
                    child: Column(
                      children: [
                        _SwitchTile(
                          title: 'Peringatan stok menipis',
                          subtitle: 'Notifikasi saat stok mendekati batas minimum',
                          value: _lowStockAlert,
                          onChanged: (v) => setState(() => _lowStockAlert = v),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _lowStockAlert
                              ? _ThresholdPicker(
                                  value: _thresholdDays,
                                  onChanged: (d) =>
                                      setState(() => _thresholdDays = d),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        const _Divider(),
                        _SwitchTile(
                          title: 'Peringatan stok habis',
                          subtitle: 'Notifikasi segera saat stok mencapai 0',
                          value: _outOfStockAlert,
                          onChanged: (v) =>
                              setState(() => _outOfStockAlert = v),
                        ),
                        const _Divider(),
                        _SwitchTile(
                          title: 'Laporan prediksi mingguan',
                          subtitle:
                              'Ringkasan kebutuhan barang setiap awal pekan',
                          value: _weeklyReport,
                          onChanged: (v) => setState(() => _weeklyReport = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Keamanan Akun'),
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: _NavTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Ubah Kata Sandi',
                      subtitle: _passwordInfo,
                      onTap: _changePassword,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(title: 'Lainnya'),
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 4),
                    child: Column(
                      children: [
                        _NavTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Bantuan & Dukungan',
                          subtitle: 'Pertanyaan umum dan kontak tim',
                          onTap: () => _toast('Halaman bantuan belum tersedia'),
                        ),
                        const _Divider(),
                        _NavTile(
                          icon: Icons.info_outline_rounded,
                          title: 'Tentang UMKM Sight',
                          subtitle: 'Versi 1.0.0',
                          onTap: () => _toast('UMKM Sight versi 1.0.0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SoftCard(
                    onTap: _logout,
                    radius: 20,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: _kRed, size: 22),
                        SizedBox(width: 10),
                        Text('Keluar Akun',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _kRed)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text('UMKM Sight  ·  Versi 1.0.0',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Bar atas dengan tombol kembali ----------
class _ProfileBar extends StatelessWidget {
  const _ProfileBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textDark, size: 26),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text('Profil & Pengaturan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }
}

// ---------- Kartu profil ----------
class _ProfileCard extends StatelessWidget {
  final String name, email, role;
  final VoidCallback onEdit;
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.role,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
                  ),
                ),
                child: Text(_initials(name),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kBadgeBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(role,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.edit_outlined,
                        size: 22, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _kBox,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(child: _MiniStat(value: '48', label: 'Item aktif')),
                _VLine(),
                Expanded(child: _MiniStat(value: '126', label: 'Transaksi/bulan')),
                _VLine(),
                Expanded(child: _MiniStat(value: 'Jan 2025', label: 'Bergabung')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: _kDivider);
}

// ---------- Judul seksi ----------
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(action!,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: _kDivider);
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: AppColors.primary),
    );
  }
}

// ---------- Baris informasi ----------
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Baris tombol navigasi ----------
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _IconBox(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ---------- Baris saklar ----------
class _SwitchTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : _kSwitchOff,
            ),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ---------- Pilihan ambang peringatan ----------
class _ThresholdPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ThresholdPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kBox,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kirim peringatan saat estimasi habis dalam',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final d in const [3, 5, 7]) ...[
                  GestureDetector(
                    onTap: () => onChanged(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: d == value
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$d hari',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: d == value
                                  ? Colors.white
                                  : AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Form isian dalam bentuk bottom sheet (dipakai untuk semua tombol "Ubah")
// =====================================================================
class _Field {
  final String label, initial;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboard;
  const _Field(
    this.label, {
    this.initial = '',
    this.obscure = false,
    this.maxLines = 1,
    this.keyboard,
  });
}

Future<List<String>?> _showFormSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<_Field> fields,
  String? Function(List<String> values)? validate,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FormSheet(
      title: title,
      subtitle: subtitle,
      fields: fields,
      validate: validate,
    ),
  );
}

class _FormSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<_Field> fields;
  final String? Function(List<String> values)? validate;
  const _FormSheet({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.validate,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final List<TextEditingController> _ctrls = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = _ctrls.map((c) => c.text.trim()).toList();
    final err = widget.validate?.call(values);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 18),
              for (var i = 0; i < widget.fields.length; i++) ...[
                Text(widget.fields[i].label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ctrls[i],
                  obscureText: widget.fields[i].obscure,
                  maxLines: widget.fields[i].maxLines,
                  keyboardType: widget.fields[i].keyboard,
                  cursorColor: AppColors.primary,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.textDark),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.chip,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kRed)),
                ),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}