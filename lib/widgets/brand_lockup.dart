import 'package:flutter/material.dart';

import 'package:collab/utils/app_assets.dart';
import 'package:collab/utils/theme.dart';

/// Logo + tulisan "Collab" berdampingan, seperti brand sheet.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 40});

  /// Tinggi logo; tulisan menyesuaikan.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppAssets.logoMark, width: size, height: size),
        SizedBox(width: size * 0.25),
        Text(
          'Collab',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: size * 0.8,
            height: 1,
            fontWeight: FontWeight.w800,
            color: ItsColors.blue,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
