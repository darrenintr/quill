import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 typography scale for Quill.
///
/// We follow Google's M3 type scale closely, but tune the display and headline
/// families to feel a little more "writerly" — perfect for a note-taking app.
/// Default body text uses [GoogleFonts.inter] for excellent legibility on
/// both compact iPad screens and large desktop windows.
class AppTypography {
  AppTypography._();

  /// Brand display family. Slightly serif-leaning, evokes paper & ink.
  static TextTheme buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.blackMountainView
        : Typography.whiteMountainView;

    final inter = GoogleFonts.interTextTheme(base);
    final display = GoogleFonts.newsreaderTextTheme(base);

    return inter.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.25,
        height: 1.16,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.22,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: inter.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: inter.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: inter.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: inter.bodyMedium?.copyWith(height: 1.45),
      labelLarge: inter.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: inter.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}