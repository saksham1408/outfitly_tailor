import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_service.dart';
import '../domain/tailor_profile.dart';

/// Partner-facing account screen.
///
/// Read side renders a compact header (avatar initial + name + email)
/// and a "Partner details" card with the editable fields. Tapping
/// EDIT flips the card into a form; SAVE persists via
/// [ProfileService.updateMine] and flips back on success.
///
/// The email field is read-only — changing it goes through Supabase
/// Auth's email-change flow which is out of scope for this screen.
/// Everything else (full name, phone, years of experience) is
/// editable and validated client-side before the network round-trip.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();

  TailorProfile? _profile;
  Object? _error;

  bool _editing = false;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _error = p == null ? 'Profile not found.' : null;
      });
      if (p != null) _seedControllers(p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _seedControllers(TailorProfile p) {
    _nameCtrl.text = p.fullName;
    _phoneCtrl.text = p.phone;
    _expCtrl.text = p.experienceYears.toString();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final years = int.parse(_expCtrl.text.trim());
      final updated = await _service.updateMine(
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        experienceYears: years,
      );
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AppSupabase.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/radar'),
        ),
        title: const Text('Account'),
        actions: [
          if (_profile != null && !_editing)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('EDIT'),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return _ErrorBlock(
        message: _error.toString(),
        onRetry: () {
          setState(() {
            _error = null;
            _profile = null;
          });
          _load();
        },
      );
    }
    final p = _profile;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final email = AppSupabase.client.auth.currentUser?.email ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(profile: p, email: email),
          const SizedBox(height: 28),
          _sectionLabel('PARTNER DETAILS'),
          const SizedBox(height: 12),
          _editing ? _buildEditForm() : _buildReadCard(p, email),
          const SizedBox(height: 28),
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildReadCard(TailorProfile p, String email) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _ReadRow(label: 'Full name', value: p.fullName),
          const _Divider(),
          _ReadRow(label: 'Email', value: email, disabled: true),
          const _Divider(),
          _ReadRow(label: 'Phone', value: p.phone),
          const _Divider(),
          _ReadRow(
            label: 'Experience',
            value: p.experienceYears == 1
                ? '1 year'
                : '${p.experienceYears} years',
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              ],
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _expCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration:
                  const InputDecoration(labelText: 'Years of experience'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 0 || n > 99) {
                  return 'Enter a whole number between 0 and 99';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() => _editing = false);
                            // Reset controllers so a cancelled edit
                            // doesn't leak its draft into the next
                            // open.
                            _seedControllers(_profile!);
                          },
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('SAVE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.email});

  final TailorProfile profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final initial = profile.fullName.trim().isEmpty
        ? '?'
        : profile.fullName.trim()[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: text.headlineSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.label,
    required this.value,
    this.disabled = false,
  });

  final String label;
  final String value;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color:
                    disabled ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
          ),
          if (disabled)
            Icon(Icons.lock_outline,
                size: 16, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Could not load your profile.',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}
