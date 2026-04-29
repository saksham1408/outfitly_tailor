import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_service.dart';
import '../domain/tailor_profile.dart';
import 'widgets/portfolio_gallery.dart';

/// Partner-facing account screen — the tailor's professional
/// workstation header.
///
/// Layout:
///   1. Header: avatar + full name + Outfitly Verified Master badge
///   2. Stats row: Rating (★ 4.8 · N reviews) and Jobs Completed
///   3. Specialties section: Wrap of Chips with an EDIT affordance
///   4. My Work: portfolio gallery with upload CTA
///   5. Partner details card (legacy editable fields)
///   6. Sign out
///
/// The header + stats + specialties form the public credibility
/// surface — what a customer effectively sees on the customer-app
/// tailor card. Editing them updates the same `tailor_profiles` row
/// that drives that customer view, so changes here ripple through.
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

  Future<void> _editSpecialties() async {
    final current = _profile?.specialties ?? const <String>[];
    final updated = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) =>
          _SpecialtiesEditorSheet(initial: current),
    );

    if (updated == null) return; // Cancelled.
    try {
      final saved = await _service.updateSpecialties(updated);
      if (!mounted) return;
      setState(() => _profile = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specialties updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save specialties: $e')),
      );
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
    // Mocked completed-jobs counter for now — surfaces alongside the
    // rating in the stats row. Will be sourced from
    // count(tailor_appointments where status='completed') once the
    // earnings feature swaps off mock data.
    final jobsCompleted = _mockJobsCompleted(p);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(profile: p, email: email),
          const SizedBox(height: 20),
          _StatsRow(profile: p, jobsCompleted: jobsCompleted),
          const SizedBox(height: 28),
          _sectionLabel('SPECIALTIES'),
          const SizedBox(height: 12),
          _SpecialtiesSection(
            specialties: p.specialties,
            onEdit: _editSpecialties,
          ),
          const SizedBox(height: 28),
          const PortfolioGallery(),
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

  /// Falls back to a deterministic small number derived from the
  /// rating × reviews so the row looks lived-in for new tailors.
  int _mockJobsCompleted(TailorProfile p) {
    if (p.totalReviews > 0) return p.totalReviews;
    return 0;
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
          width: 64,
          height: 64,
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.fullName,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 20,
                      color: Color(0xFFE8B53D), // Gold checkmark
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (profile.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8B53D).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'OUTFITLY VERIFIED MASTER',
                    style: text.labelSmall?.copyWith(
                      color: const Color(0xFFE8B53D),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      fontSize: 10,
                    ),
                  ),
                )
              else
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

/// Two-stat row sitting under the header. Rating on the left, Jobs
/// Completed on the right, with a thin divider between.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile, required this.jobsCompleted});

  final TailorProfile profile;
  final int jobsCompleted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratingDisplay =
        profile.rating > 0 ? profile.rating.toStringAsFixed(1) : '—';
    final reviewsDisplay = profile.totalReviews > 0
        ? '${profile.totalReviews} review${profile.totalReviews == 1 ? '' : 's'}'
        : 'No reviews yet';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: Color(0xFFFFC15C)),
                    const SizedBox(width: 4),
                    Text(
                      ratingDisplay,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reviewsDisplay,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: AppColors.divider,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  jobsCompleted.toString(),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jobsCompleted == 1 ? 'Job completed' : 'Jobs completed',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
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

/// Section showing the tailor's specialty tags as a [Wrap] of
/// [Chip]s, with an inline EDIT button that opens a bottom-sheet
/// editor.
class _SpecialtiesSection extends StatelessWidget {
  const _SpecialtiesSection({
    required this.specialties,
    required this.onEdit,
  });

  final List<String> specialties;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  specialties.isEmpty
                      ? 'What do you specialize in?'
                      : 'What you make',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: const Text('EDIT'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (specialties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Add tags like "Sherwanis", "Suits", "Blouses" so customers know what you\'re best at.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in specialties)
                    _SpecialtyChip(label: tag),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Modal sheet for adding/removing specialties.
///
/// Type a tag, hit Enter (or the + button) to add it. Tap the × on
/// any chip to remove it. SAVE returns the new list to the caller;
/// CANCEL returns null.
class _SpecialtiesEditorSheet extends StatefulWidget {
  const _SpecialtiesEditorSheet({required this.initial});

  final List<String> initial;

  @override
  State<_SpecialtiesEditorSheet> createState() =>
      _SpecialtiesEditorSheetState();
}

class _SpecialtiesEditorSheetState extends State<_SpecialtiesEditorSheet> {
  late final List<String> _tags = [...widget.initial];
  final _ctrl = TextEditingController();
  static const _suggestions = <String>[
    'Sherwanis',
    'Suits',
    'Blouses',
    'Lehengas',
    'Kurtas',
    'Sarees',
    'Anarkalis',
    'Wedding wear',
    'Alterations',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == v.toLowerCase())) return;
    setState(() {
      _tags.add(v);
      _ctrl.clear();
    });
  }

  void _remove(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Suggestions not yet picked.
    final remainingSuggestions = _suggestions
        .where((s) =>
            !_tags.any((t) => t.toLowerCase() == s.toLowerCase()))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit Specialties',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customers see these on your tailor card.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),
              if (_tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      _RemovableChip(
                        label: tag,
                        onRemove: () => _remove(tag),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _add,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Sherwanis',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: () => _add(_ctrl.text),
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(52, 52),
                    ),
                  ),
                ],
              ),
              if (remainingSuggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'SUGGESTIONS',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in remainingSuggestions)
                      InkWell(
                        onTap: () => _add(s),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  size: 14,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                s,
                                style: text.labelMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_tags),
                      child: const Text('SAVE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded,
                  size: 14, color: AppColors.accent),
            ),
          ),
        ],
      ),
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
