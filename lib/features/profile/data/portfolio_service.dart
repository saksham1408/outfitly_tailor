import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/portfolio_item.dart';

/// Read/write seam for the tailor's portfolio gallery.
///
/// Rows live in the `tailor_portfolios` table; the actual image
/// bytes live in the `tailor_portfolios` Supabase Storage bucket.
/// Both are scoped per-tailor via RLS on `tailor_id = auth.uid()`.
///
/// Upload flow:
///   1. Stream the file bytes to `tailor_portfolios/{uid}/{ts}.jpg`
///   2. Resolve the public URL for the uploaded path
///   3. Insert a row into `tailor_portfolios` with that URL
///
/// We do storage first → DB second so a row never references a
/// missing object. If the DB insert fails the orphan blob is
/// cleaned up in step (4).
class PortfolioService {
  PortfolioService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'tailor_portfolios';
  static const String _bucket = 'tailor_portfolios';

  /// All portfolio items for the signed-in tailor, newest first.
  Future<List<PortfolioItem>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot fetch portfolio while signed out.');
    }

    final rows = await _client
        .from(_table)
        .select()
        .eq('tailor_id', uid)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PortfolioItem.fromJson)
        .toList(growable: false);
  }

  /// Upload a local image file and create the matching DB row.
  ///
  /// Returns the inserted [PortfolioItem]. Throws on either the
  /// storage upload OR the DB insert failing. On insert failure
  /// we attempt a best-effort cleanup of the just-uploaded blob
  /// so we don't leak storage on retries.
  Future<PortfolioItem> uploadFromFile({
    required File file,
    String? description,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot upload portfolio item while signed out.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _extOf(file.path);
    final objectPath = '$uid/$timestamp$ext';

    await _client.storage.from(_bucket).upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: _mimeOf(ext),
            upsert: false,
          ),
        );

    final publicUrl =
        _client.storage.from(_bucket).getPublicUrl(objectPath);

    try {
      final inserted = await _client
          .from(_table)
          .insert({
            'tailor_id': uid,
            'image_url': publicUrl,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
          })
          .select()
          .single();

      return PortfolioItem.fromJson(inserted);
    } catch (e) {
      // Best-effort orphan cleanup. Failure to remove is logged
      // implicitly by Supabase; we still rethrow the original.
      try {
        await _client.storage.from(_bucket).remove([objectPath]);
      } catch (_) {/* swallow — original error is more useful */}
      rethrow;
    }
  }

  /// In-memory variant used when [image_picker] returns bytes (web
  /// or pickers that opt out of file system access). Mirrors
  /// [uploadFromFile] otherwise.
  Future<PortfolioItem> uploadFromBytes({
    required Uint8List bytes,
    required String fileName,
    String? description,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Cannot upload portfolio item while signed out.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _extOf(fileName);
    final objectPath = '$uid/$timestamp$ext';

    await _client.storage.from(_bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeOf(ext),
            upsert: false,
          ),
        );

    final publicUrl =
        _client.storage.from(_bucket).getPublicUrl(objectPath);

    try {
      final inserted = await _client
          .from(_table)
          .insert({
            'tailor_id': uid,
            'image_url': publicUrl,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
          })
          .select()
          .single();

      return PortfolioItem.fromJson(inserted);
    } catch (e) {
      try {
        await _client.storage.from(_bucket).remove([objectPath]);
      } catch (_) {}
      rethrow;
    }
  }

  static String _extOf(String pathOrName) {
    final dot = pathOrName.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return pathOrName.substring(dot).toLowerCase();
  }

  static String _mimeOf(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
