import 'package:flutter/foundation.dart';

/// One image in a tailor's portfolio gallery.
///
/// Mirrors the `tailor_portfolios` table:
///   * [id]          — row PK, UUID
///   * [tailorId]    — owning tailor's auth.users.id (RLS scope)
///   * [imageUrl]    — public URL into the `tailor_portfolios`
///                     Supabase Storage bucket
///   * [description] — optional caption (e.g. "Cream sherwani for
///                     sangeet, hand-embroidered cuffs")
///   * [createdAt]   — server timestamp, used for grid ordering
///
/// [fromJson] is tolerant of a missing description so a half-uploaded
/// row (record inserted before the file finished streaming) still
/// renders rather than crashing the gallery.
@immutable
class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.tailorId,
    required this.imageUrl,
    this.description,
    this.createdAt,
  });

  final String id;
  final String tailorId;
  final String imageUrl;
  final String? description;
  final DateTime? createdAt;

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id']?.toString() ?? '',
      tailorId: json['tailor_id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      description: (json['description'] as String?)?.trim().isEmpty == true
          ? null
          : json['description']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  PortfolioItem copyWith({
    String? imageUrl,
    String? description,
  }) {
    return PortfolioItem(
      id: id,
      tailorId: tailorId,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
