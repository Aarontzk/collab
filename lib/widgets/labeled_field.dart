import 'package:flutter/material.dart';

/// Label tebal di atas field (gaya form Spotify), bukan label melayang.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
  });

  final String label;
  final Widget child;

  /// Tambah keterangan "(Opsional)" tipis di belakang label.
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (optional)
                TextSpan(
                  text: ' (Opsional)',
                  style: style?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          style: style,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
