import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:collab/utils/material_theme.dart';

/// Palet app. Peran warnanya diambil dari Material Theme Builder
/// (core colors ITS: #243F81, #127BBE, #FDBB16), lihat material_theme.dart.
/// Pasangan warna (container + isi) dipakai apa adanya, jangan ditukar.
abstract final class ItsColors {
  static const blue = Color(0xFF4A5C92); // primary
  static const blueContainer = Color(0xFFDBE1FF);
  static const onBlueContainer = Color(0xFF314578);

  static const skyBlue = Color(0xFF30628C); // secondary
  static const skyContainer = Color(0xFFCEE5FF);
  static const onSkyContainer = Color(0xFF0F4A73);

  static const lightBlue = Color(0xFF9CCBFB); // secondaryFixedDim

  /// Kuning ITS asli dipertahankan sebagai aksen (bintang, sorotan).
  /// Tertiary hasil builder (#79590C) terlalu cokelat untuk peran itu.
  static const yellow = Color(0xFFFDBB16);
  static const yellowContainer = Color(0xFFFFDEA4); // tertiaryContainer
  static const onYellowContainer = Color(0xFF5D4200);

  static const ink = Color(0xFF1A1B21); // onSurface
  static const inkMuted = Color(0xFF45464F); // onSurfaceVariant
  static const inverseSurface = Color(0xFF2F3036);

  static const background = Colors.white;
  static const surfaceLow = Color(0xFFF4F3FA); // surfaceContainerLow
  static const surfaceContainer = Color(0xFFEEEDF4);
  static const border = Color(0xFFE8E7EF); // surfaceContainerHigh
}

/// Token shape dari koleksi variabel "Shape" (M3) di Figma.
abstract final class AppShape {
  static const extraSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 28.0;
}

/// Skema warna dari Material Theme Builder (lihat material_theme.dart).
final _colorScheme = MaterialTheme.lightScheme().copyWith(
  // Latar app tetap putih bersih seperti di Figma.
  surface: Colors.white,
);

/// Nama font family yang didaftarkan di pubspec.yaml (file di assets/fonts/).
abstract final class AppFonts {
  /// Plus Jakarta Sans: font buatan desainer Indonesia, untuk teks umum.
  static const text = 'PlusJakartaSans';

  /// Poppins: teks body (paragraf, isi list, isian form).
  static const body = 'Poppins';

  /// Roboto: font komponen kit M3 di Figma (tombol, chip).
  static const component = 'Roboto';
}

final _baseTextTheme = ThemeData(useMaterial3: true).textTheme.apply(
  fontFamily: AppFonts.text,
  bodyColor: ItsColors.ink,
  displayColor: ItsColors.ink,
);

/// Tracking ikut ukuran (gaya Apple): judul besar dirapatkan -2%,
/// teks sedang 0, teks kecil sedikit dilonggarkan.
TextStyle? _tracked(TextStyle? style) {
  final size = style?.fontSize;
  if (style == null || size == null) return style;
  final spacing = size >= 20 ? -0.02 * size : (size <= 12 ? 0.1 : 0.0);
  return style.copyWith(
    letterSpacing: spacing,
    height: size >= 28 ? 1.1 : style.height,
  );
}

/// Judul pakai Plus Jakarta Sans, gaya body* pakai Poppins.
final _textTheme = _baseTextTheme.copyWith(
  displayLarge: _tracked(_baseTextTheme.displayLarge),
  displayMedium: _tracked(_baseTextTheme.displayMedium),
  displaySmall: _tracked(_baseTextTheme.displaySmall),
  headlineLarge: _tracked(_baseTextTheme.headlineLarge),
  headlineMedium: _tracked(_baseTextTheme.headlineMedium),
  headlineSmall: _tracked(_baseTextTheme.headlineSmall),
  titleLarge: _tracked(_baseTextTheme.titleLarge),
  titleMedium: _tracked(_baseTextTheme.titleMedium),
  bodyLarge: _tracked(
    _baseTextTheme.bodyLarge?.copyWith(fontFamily: AppFonts.body),
  ),
  bodyMedium: _tracked(
    _baseTextTheme.bodyMedium?.copyWith(fontFamily: AppFonts.body),
  ),
  bodySmall: _tracked(
    _baseTextTheme.bodySmall?.copyWith(fontFamily: AppFonts.body),
  ),
);

RoundedRectangleBorder _rounded(double radius, {BorderSide? side}) =>
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side ?? BorderSide.none,
    );

OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppShape.medium),
      borderSide: BorderSide(color: color, width: width),
    );

/// Label tombol persis komponen Button ITS di Figma: Roboto Medium 14, tracking 0.1.
const _buttonText = TextStyle(
  fontFamily: AppFonts.component,
  fontSize: 14,
  height: 20 / 14,
  letterSpacing: 0.1,
  fontWeight: FontWeight.w500,
);

/// "Size=Small" komponen Button ITS: tinggi 40, padding 16, ikon 20.
const _buttonSize = Size(64, 40);
const _buttonPadding = EdgeInsets.symmetric(horizontal: 16);

final collabTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _colorScheme,
  textTheme: _textTheme.copyWith(
    headlineLarge: _textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: _textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleLarge: _textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: _textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  ),
  scaffoldBackgroundColor: ItsColors.background,
  // Transisi halaman gaya iOS di semua platform: masuk dari kanan, keluar
  // ke kanan lewat jalur yang sama, dan bisa diseret balik dari tepi kiri
  // (gerakan ikut jari dan kecepatannya, bisa dibatalkan di tengah jalan).
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: CupertinoPageTransitionsBuilder(),
    },
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: ItsColors.background,
    foregroundColor: ItsColors.ink,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: _textTheme.titleLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: ItsColors.blue,
    ),
  ),
  // Outlined card M3: putih, garis tipis, radius Large.
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: _rounded(
      AppShape.large,
      side: const BorderSide(color: ItsColors.border),
    ),
  ),
  // Tombol = komponen Button / Button - outline / Button - text ITS
  // (Type=Round, Size=Small). Ikuti Figma, jangan diubah sendiri.
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: const StadiumBorder(),
      backgroundColor: ItsColors.blue,
      foregroundColor: Colors.white,
      iconSize: 20,
      textStyle: _buttonText,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: const StadiumBorder(),
      foregroundColor: ItsColors.inkMuted,
      iconColor: ItsColors.inkMuted,
      iconSize: 20,
      side: const BorderSide(color: Color(0xFFC4C6D0)),
      textStyle: _buttonText,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: _buttonSize,
      padding: _buttonPadding,
      shape: const StadiumBorder(),
      foregroundColor: ItsColors.blue,
      iconSize: 20,
      textStyle: _buttonText,
    ),
  ),
  // FAB "Tertiary container" dari komponen FAB ITS: kuning muda + isi gelap.
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: ItsColors.yellowContainer,
    foregroundColor: ItsColors.onYellowContainer,
    elevation: 3,
    shape: _rounded(AppShape.large),
    extendedTextStyle: _buttonText,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _inputBorder(const Color(0xFFC4C6D0)),
    enabledBorder: _inputBorder(const Color(0xFFC4C6D0)),
    focusedBorder: _inputBorder(ItsColors.blue, 2),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    menuStyle: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      shape: WidgetStatePropertyAll(_rounded(AppShape.extraSmall)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: ItsColors.surfaceLow,
    surfaceTintColor: Colors.transparent,
    indicatorColor: ItsColors.skyContainer,
    elevation: 0,
    height: 80,
    // Sama dengan Collab/Navigation bar di Figma: ikon garis abu tua,
    // label Plus Jakarta Sans SemiBold 12 (aktif lebih gelap).
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(color: Color(0xFF49454F), size: 24),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: AppFonts.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: states.contains(WidgetState.selected)
            ? ItsColors.ink
            : ItsColors.inkMuted,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: _rounded(AppShape.small),
    side: const BorderSide(color: Color(0xFFC4C6D0)),
    selectedColor: ItsColors.skyContainer,
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      selectedBackgroundColor: ItsColors.skyContainer,
      selectedForegroundColor: ItsColors.onSkyContainer,
    ),
  ),
  listTileTheme: ListTileThemeData(shape: _rounded(AppShape.medium)),
  dividerTheme: const DividerThemeData(color: ItsColors.border, space: 1),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ItsColors.inverseSurface,
    shape: _rounded(AppShape.extraSmall),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppShape.extraLarge),
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: _rounded(AppShape.extraLarge),
  ),
);
