import 'package:flutter/material.dart';

/// Presentación común de los paneles; no interviene en datos ni permisos.
ThemeData temaLigaMaster() {
  const azul = Color(0xFF4351BF);
  const superficie = Color(0xFFF8F6FB);
  final borde = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: azul,
    ).copyWith(primary: azul, surface: superficie),
    scaffoldBackgroundColor: const Color(0xFFF2F2F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: azul,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFAAA7B5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: azul, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        minimumSize: const Size(132, 44),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: borde,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: azul,
        minimumSize: const Size(100, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: borde,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: azul,
        minimumSize: const Size(80, 44),
        shape: borde,
      ),
    ),
    cardTheme: CardThemeData(
      color: superficie,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE3E0ED)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    ),
  );
}

/// Limita campos largos en escritorio y aprovecha el ancho disponible en móvil.
class ControlCentrado extends StatelessWidget {
  const ControlCentrado({super.key, required this.child, this.ancho = 520});
  final Widget child;
  final double ancho;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: ancho),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
