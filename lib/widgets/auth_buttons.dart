import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:collab/services/auth_service.dart';
import 'package:collab/utils/app_assets.dart';
import 'package:collab/widgets/common_widgets.dart';

/// Tulisan "atau" + tombol MyITS (Button ITS) dan Google (Button - outline ITS).
/// Dipakai di halaman masuk dan daftar. [verb] contoh: "Masuk" atau "Daftar".
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key, required this.verb});
  final String verb;

  Future<void> _google(BuildContext context) async {
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  void _myIts(BuildContext context) {
    showMessage(
      context,
      'Login myITS SSO belum aktif. Masih menunggu client ID dari DPTSI ITS, '
      'sementara pakai email dulu ya.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'atau',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _myIts(context),
          child: _LeadingLogoLabel(
            logo: Image.asset(
              AppAssets.itsLogoWhite,
              width: 20,
              height: 20,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            label: '$verb dengan MyITS',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _google(context),
          child: _LeadingLogoLabel(
            logo: SvgPicture.asset(AppAssets.googleG, width: 18, height: 18),
            label: '$verb dengan Google',
          ),
        ),
      ],
    );
  }
}

/// Logo rata kiri di tepi tombol, tulisan tetap di tengah.
class _LeadingLogoLabel extends StatelessWidget {
  const _LeadingLogoLabel({required this.logo, required this.label});
  final Widget logo;
  final String label;

  static const _slot = 20.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _slot,
          child: Center(child: logo),
        ),
        Expanded(child: Text(label, textAlign: TextAlign.center)),
        // Penyeimbang supaya tulisan benar-benar di tengah tombol.
        const SizedBox(width: _slot),
      ],
    );
  }
}
