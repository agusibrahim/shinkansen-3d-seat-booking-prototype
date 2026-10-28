import 'package:flutter/material.dart';

enum AppColorTheme { light, dark }

class DesignSystem extends ChangeNotifier {
  static final DesignSystem instance = DesignSystem._();
  DesignSystem._();

  AppColorTheme _theme = AppColorTheme.light;
  AppColorTheme get theme => _theme;
  bool get isDark => _theme == AppColorTheme.dark;

  void setTheme(AppColorTheme next) {
    if (_theme != next) {
      _theme = next;
      notifyListeners();
    }
  }

  // Accent Colors (Colors.swift)
  static const Color accentMain = Color(0xFF008B3F);
  static const Color accentDark = Color(0xFF076632);
  static const Color accentLight = Color(0xFF4BB77C);

  // Basic Colors
  static const Color basicBlack = Color(0xFF000000);
  static const Color basicOffBlack = Color(0xFF212121);
  static const Color basicSlightlyBlack = Color(0xFF242424);
  static const Color basicDarkGray = Color(0xFF2E2E2E);
  static const Color basicSlightlyDarkGray = Color(0xFF3C3C3C);
  static const Color basicGray = Color(0xFF909095);
  static const Color basicOffWhite = Color(0xFFFAFAFA);
  static const Color basicWhite = Color(0xFFFFFFFF);

  // Miscellaneous Colors
  static const Color miscDarkRed = Color(0xFF882743);
  static const Color miscRed = Color(0xFFCB3A64);
  static const Color miscLightRed = Color(0xFFDD6F93);

  // Design Values (DesignValues.swift)
  static const double alphaHighlighted = 0.54;
  static const double alphaDisabled = 0.25;
  static const double radiusButton = 8.0;
  static const double radiusSegmentedItem = 6.0;
  static const double radiusSegmentedControl = 12.0;
  static const double radiusCard = 8.0;
  static const double radiusLargeCard = 20.0;
  static const double cardGutter = 16.0;
  static const double maxWidth = 540.0;
  static const double layoutMargin = 20.0;

  // Component Colors by Theme
  Color get background => isDark ? basicOffBlack : basicOffWhite;
  Color get cardBackground => isDark ? basicDarkGray : basicWhite;
  Color get cardAltBackground => isDark ? basicSlightlyDarkGray : basicWhite;
  Color get cardDisabledBackground => isDark ? basicSlightlyBlack : basicWhite;
  Color get primaryText => isDark ? basicWhite : basicBlack;
  Color get secondaryText => basicGray;
  Color get callToAction => isDark ? basicWhite : accentMain;
  Color get callToActionHighlighted =>
      isDark ? basicWhite.withValues(alpha: alphaHighlighted) : accentDark;
  Color get callToActionDisabled => basicGray;
  Color get contentOnCallToAction => isDark ? basicOffBlack : basicWhite;
  Color get errorBackground => isDark ? miscRed : miscLightRed;

  // Seat Class Icon Colors (7 KAI Classes)
  Color seatClassColor(String seatClass) {
    switch (seatClass) {
      case 'granClass':
        return isDark ? const Color(0xFFDFD494) : const Color(0xFFBB9E00);
      case 'eksekutifDualTone':
        return isDark ? const Color(0xFF66C8EB) : const Color(0xFF0E86B0);
      case 'green':
        return isDark ? const Color(0xFFBEF186) : const Color(0xFF7ED321);
      case 'ekonomiNewGenDual':
        return isDark ? const Color(0xFF82A6E0) : const Color(0xFF36588F);
      case 'ekonomiPremium':
        return isDark ? const Color(0xFFD6B28E) : const Color(0xFFA67C52);
      case 'ekonomiTosca':
        return isDark ? const Color(0xFF7CE0F5) : const Color(0xFF2CA8C2);
      case 'ordinary':
      default:
        return isDark ? const Color(0xFFAFE8C9) : const Color(0xFF008B3F);
    }
  }

  // Shadows (LayerStyle.swift)
  static List<BoxShadow> get cardNormalShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get cardHighlightedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardDisabledShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  // Text Styles (TextStyle.swift)
  static TextStyle largeTitle({Color? color, bool narrow = false}) => TextStyle(
        fontSize: narrow ? 28 : 34,
        fontWeight: FontWeight.w300,
        height: 1.18,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle title1({Color? color}) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.2,
        color: color,
      );

  static TextStyle headline({Color? color}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  static TextStyle subheadline({Color? color}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 22 / 18,
        color: color,
      );

  static TextStyle button({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      );

  static TextStyle outlinedButton({Color? color}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle footnote({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.25,
        letterSpacing: 0.3,
        color: color,
      );

  static TextStyle caption1({Color? color}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.3,
        color: color,
      );

  static TextStyle caption1Alt({Color? color}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color,
      );

  static TextStyle caption2({Color? color}) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: color,
      );
}
