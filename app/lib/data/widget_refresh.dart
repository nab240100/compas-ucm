/// Puente con el widget de Android: tras guardar la instantánea, se pide al
/// widget que se vuelva a dibujar (solo Android; en el resto es un no-op).
library;

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('compas_ucm/widgets');

Future<void> refreshWeekWidget() async {
  try {
    await _channel.invokeMethod<void>('refreshWeek');
  } on MissingPluginException {
    // No Android / widget sin registrar: silencioso.
  } catch (_) {
    // Fallo puntual del canal: nunca debe romper la app.
  }
}
