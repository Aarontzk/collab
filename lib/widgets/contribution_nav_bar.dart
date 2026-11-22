import 'package:flutter/material.dart';

import 'package:collab/widgets/common_widgets.dart';

/// Navigasi bawah dengan tab Kontribusi aktif.
class ContributionNavBar extends StatelessWidget {
  const ContributionNavBar({super.key, this.onSelected});

  /// Kalau diisi, tab lain meneruskan indeksnya ke pemanggil.
  final ValueChanged<int>? onSelected;

  static const _labels = ['Tugas', 'Rapat', 'Review', 'Kontribusi'];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 3,
      onDestinationSelected: (index) {
        if (index == 3) return;
        final callback = onSelected;
        if (callback != null) {
          callback(index);
          return;
        }
        showMessage(context, 'Halaman ${_labels[index]} belum tersedia');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist),
          label: 'Tugas',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Rapat',
        ),
        NavigationDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review),
          label: 'Review',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Kontribusi',
        ),
      ],
    );
  }
}
