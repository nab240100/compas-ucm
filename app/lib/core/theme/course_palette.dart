import 'package:flutter/material.dart';

/// Paleta cálida y estable por asignatura.
///
/// Cada asignatura recibe un par (contenedor, texto) determinista a partir de
/// su código, armonizado con el fondo crema del tema. Los pares están
/// elegidos a mano para mantener la sensación "cozy" (tonos tierra, salvia,
/// miel, azul suave y lila) y buen contraste de texto.
class CoursePalette {
  CoursePalette._();

  static const List<(Color, Color)> _pairs = [
    (Color(0xFFF5C8B0), Color(0xFF5F2E1C)), // terra suave
    (Color(0xFFDDE7C0), Color(0xFF35401F)), // salvia viva
    (Color(0xFFFBDC9E), Color(0xFF60440E)), // miel
    (Color(0xFFC9DDF0), Color(0xFF24405A)), // azul bruma
    (Color(0xFFE4D3F5), Color(0xFF45315D)), // lila
    (Color(0xFFF6CBD4), Color(0xFF5C2E3A)), // rosa arcilla
    (Color(0xFFCFEBDD), Color(0xFF25463A)), // menta
    (Color(0xFFF2DCC0), Color(0xFF57432B)), // arena
    (Color(0xFFD3E2ED), Color(0xFF33414C)), // gris azulado
    (Color(0xFFFAD5B8), Color(0xFF5C3B24)), // melocotón
    (Color(0xFFD6E3C8), Color(0xFF3A4A3C)), // oliva
    (Color(0xFFEFD0E4), Color(0xFF553A50)), // malva
  ];

  static int _index(String code) {
    var sum = 0;
    for (final u in code.codeUnits) {
      sum = (sum + u) % _pairs.length;
    }
    return sum;
  }

  static Color containerOf(String courseCode) => _pairs[_index(courseCode)].$1;

  static Color onContainerOf(String courseCode) => _pairs[_index(courseCode)].$2;
}
