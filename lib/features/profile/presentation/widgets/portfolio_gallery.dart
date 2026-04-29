import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/portfolio_service.dart';
import '../../domain/portfolio_item.dart';

/// "My Work" gallery embedded inside the Profile screen.
///
/// Renders a 3-column [GridView] of the tailor's [PortfolioItem]s
/// with an "Add to Portfolio" floating CTA. Tapping the CTA opens
/// the device gallery via [image_picker]; the picked image is
/// uploaded to the `tailor_portfolios` Supabase bucket and a
/// matching row is inserted via [PortfolioService.uploadFromFile].
///
/// We use a plain Container "FAB" instead of a Scaffold-level
/// FloatingActionButton because this widget is a section inside a
/// scrolling profile screen, not a full-screen surface. A pinned
/// FAB would float over the bottom nav and visually disconnect
/// from the gallery.
class PortfolioGallery extends StatefulWidget {
  const PortfolioGallery({super.key});

  @override
  State<PortfolioGallery> createState() => _PortfolioGalleryState();
}

class _PortfolioGalleryState extends State<PortfolioGallery> {
  final PortfolioService _service = PortfolioService();
  final ImagePicker _picker = ImagePicker();

  List<PortfolioItem>? _items;
  Object? _error;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // Cap the long edge so we aren't shipping 12MP raw files into
      // Storage — the gallery thumbnails are tiny anyway.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      // On web, image_picker hands back bytes; everywhere else
      // a path is available. Branch so we don't try to `File()`
      // a virtual blob URL.
      late final PortfolioItem inserted;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        inserted = await _service.uploadFromBytes(
          bytes: bytes,
          fileName: picked.name,
        );
      } else {
        inserted = await _service.uploadFromFile(file: File(picked.path));
      }

      if (!mounted) return;
      setState(() {
        _items = [inserted, ...?_items];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to portfolio.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'MY WORK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _AddButton(
              busy: _uploading,
              onTap: _pickAndUpload,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGrid(),
      ],
    );
  }

  Widget _buildGrid() {
    if (_error != null) {
      return _ErrorTile(
        message: _error.toString(),
        onRetry: _load,
      );
    }
    final items = _items;
    if (items == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return _EmptyTile(onAdd: _pickAndUpload);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _PortfolioTile(item: items[i]),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              const Icon(
                Icons.add_a_photo_outlined,
                size: 16,
                color: AppColors.accent,
              ),
            const SizedBox(width: 6),
            Text(
              busy ? 'UPLOADING…' : 'ADD',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({required this.item});

  final PortfolioItem item;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: AppColors.surfaceRaised,
        child: Image.network(
          item.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              'Showcase your craft',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload photos of garments you\'ve made.\nThey appear on your customer-facing card.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              size: 28, color: AppColors.textTertiary),
          const SizedBox(height: 8),
          Text(
            'Could not load portfolio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}
