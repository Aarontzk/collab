import 'package:flutter/material.dart';

import 'package:collab/utils/theme.dart';

/// Tipografi kit M3 di Figma (Roboto) untuk beranda.
abstract final class HomeText {
  /// Headline Medium, judul App bar Large.
  static const pageTitle = TextStyle(
    fontFamily: AppFonts.component,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: ItsColors.ink,
  );

  /// Title Large, judul section.
  static const section = TextStyle(
    fontFamily: AppFonts.component,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
    color: ItsColors.ink,
  );

  static const headline = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 20 / 15,
    color: ItsColors.ink,
  );

  static const supporting = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    height: 18 / 13,
    color: ItsColors.inkMuted,
  );

  /// Judul kartu (nama kelompok, angka utama).
  static const cardTitle = TextStyle(
    fontFamily: AppFonts.text,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    color: ItsColors.ink,
  );

  /// Teks keterangan kecil.
  static const meta = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 16 / 12,
    color: ItsColors.inkMuted,
  );

  /// Label pill/chip.
  static const label = TextStyle(
    fontFamily: AppFonts.text,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: ItsColors.inkMuted,
  );

  static const trailing = TextStyle(
    fontFamily: AppFonts.component,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.5,
    fontWeight: FontWeight.w500,
    color: ItsColors.inkMuted,
  );
}

/// Judul section seperti contoh kit: teks saja, tanpa kalimat penjelas.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(text, style: HomeText.section),
    );
  }
}

/// "List item" kit (2 line, Leading=Monogram): inisial, judul, satu baris pendek.
class MonogramTile extends StatelessWidget {
  const MonogramTile({
    super.key,
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String initial;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = trailing;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: const RoundedRectangleBorder(),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: ItsColors.blueContainer,
        child: Text(
          initial.characters.first.toUpperCase(),
          style: HomeText.headline.copyWith(
            color: ItsColors.onBlueContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      title: Text(
        title,
        style: HomeText.headline,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, style: HomeText.supporting),
      trailing: label == null ? null : Text(label, style: HomeText.trailing),
    );
  }
}
