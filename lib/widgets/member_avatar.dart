import 'package:flutter/material.dart';

import 'package:collab/utils/theme.dart';
import 'package:collab/widgets/home_cards.dart';

/// Avatar orang (anggota, PIC, diri sendiri) seperti "Avatar" kit M3 di Figma:
/// foto kalau `avatarUrl` ada, kalau tidak inisial di atas blue container.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
  });

  final String name;
  final String? avatarUrl;

  /// 20 = ukuran list item kit (40px).
  final double radius;

  /// Huruf pertama nama, huruf besar. Nama kosong jadi "?".
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: ItsColors.blueContainer,
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      // Foto gagal dimuat: inisial di bawahnya tetap terlihat.
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        initialOf(name),
        style: HomeText.headline.copyWith(
          fontSize: radius * 0.8,
          height: 1,
          color: ItsColors.onBlueContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
