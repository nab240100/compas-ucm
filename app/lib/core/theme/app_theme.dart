import 'package:flutter/material.dart';

/// Semillas de color para los presets "cozy" (elegidos en el onboarding).
///
/// Los esquemas se derivan siembre de estas semillas con
/// [DynamicSchemeVariant.fidelity], de modo que los roles M3 (superficies,
/// contenedores, texto) quedan armonizados y accesibles (AA) por construcción.
class AppSeeds {
  AppSeeds._();

  /// Terra — terracota cálida (por defecto). Acentos de acción y exámenes.
  static const Color terra = Color(0xFFB85C38);

  /// Salvia — verde agrisado. Descansos, días no lectivos, éxito.
  static const Color salvia = Color(0xFF6F7D5C);

  /// Miel — dorado suave. Festivos y celebraciones.
  static const Color miel = Color(0xFFB98A2F);

  /// Rosa — fresa pastel.
  static const Color rosa = Color(0xFFF2A0B4);

  /// Lavanda — lila pastel.
  static const Color lavanda = Color(0xFFB9A8E8);

  /// Celeste — cielo pastel.
  static const Color celeste = Color(0xFF9ED0F5);

  /// Menta — verde agua pastel.
  static const Color menta = Color(0xFF9FDFC0);

  /// Océano — aqua helado (paleta Ocean Blue Serenity).
  static const Color oceano = Color(0xFFB8F2E6);

  static const Color defaultSeed = terra;
}

/// Tema M3 Expressive de Compás UCM: superficies cálidas, tarjetas muy
/// redondeadas, tipografía Plus Jakarta Sans y navegación con píldora.
///
/// Los presets estáticos (semillas) usan la misma paleta que el widget de
/// horario: fondo crema (#FBF4EB) y los pasteles de asignatura (terracota,
/// salvia, miel) como contenedores y acentos. El color dinámico del fondo de
/// pantalla ([fromScheme]) se respeta tal cual.
class AppTheme {
  AppTheme._();

  static ThemeData light({Color seed = AppSeeds.defaultSeed}) =>
      _build(_cozy(seed, dark: false));

  static ThemeData dark({Color seed = AppSeeds.defaultSeed}) =>
      _build(_cozy(seed, dark: true));

  /// Tema construido sobre un esquema externo (color dinámico Material You).
  static ThemeData fromScheme(ColorScheme scheme) => _build(scheme);

  /// Cream + pasteles del widget (light) o espresso cálido (dark).
  static ColorScheme _cozy(Color seed, {required bool dark}) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    if (dark) {
      // Fondo "espresso" cálido (nada de negro puro) con contenedores pastel
      // oscurecidos para leer con los mismos acentos.
      return base.copyWith(
        surface: const Color(0xFF1B1511),
        surfaceDim: const Color(0xFF130E0B),
        surfaceBright: const Color(0xFF261E17),
        surfaceContainerLowest: const Color(0xFF110D0A),
        surfaceContainerLow: const Color(0xFF1F1913),
        surfaceContainer: const Color(0xFF26201A),
        surfaceContainerHigh: const Color(0xFF2E261E),
        surfaceContainerHighest: const Color(0xFF362D23),
        primaryContainer: const Color(0xFF6B331D),
        onPrimaryContainer: const Color(0xFFFFDBC7),
        secondaryContainer: const Color(0xFF414A2C),
        onSecondaryContainer: const Color(0xFFDDE7C0),
        tertiaryContainer: const Color(0xFF5F4512),
        onTertiaryContainer: const Color(0xFFFBDC9E),
        outlineVariant: const Color(0xFF4A4034),
      );
    }
    return base.copyWith(
      // Fondo crema del widget y variantes de superficie tostadas.
      surface: const Color(0xFFFBF4EB),
      surfaceBright: const Color(0xFFFFFAF2),
      surfaceDim: const Color(0xFFE9DEC9),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7EFE0),
      surfaceContainer: const Color(0xFFF3E8D4),
      surfaceContainerHigh: const Color(0xFFEEE0C7),
      surfaceContainerHighest: const Color(0xFFE8D8BC),
      // Pasteles de asignatura del widget como contenedores/accentos.
      primaryContainer: const Color(0xFFF5C8B0),
      onPrimaryContainer: const Color(0xFF5F2E1C),
      secondaryContainer: const Color(0xFFDDE7C0),
      onSecondaryContainer: const Color(0xFF35401F),
      tertiaryContainer: const Color(0xFFFBDC9E),
      onTertiaryContainer: const Color(0xFF60440E),
      outlineVariant: const Color(0xFFE4D6C0),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final Brightness brightness = scheme.brightness;

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
      ),
    );

    // Pesos redondeados y amables para títulos (M3 usa w400 por defecto).
    final TextTheme textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(textTheme: textTheme);
  }
}
