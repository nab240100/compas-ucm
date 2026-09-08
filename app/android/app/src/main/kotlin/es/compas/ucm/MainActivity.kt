package es.compas.ucm

import es.compas.ucm.widgets.DayWidgetReceiver
import es.compas.ucm.widgets.WeekWidgetReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "compas_ucm/widgets")
            .setMethodCallHandler { call, result ->
                if (call.method == "refreshWeek") {
                    // La app ya ha escrito la instantánea en SharedPreferences:
                    // solo hay que pedir a los widgets que se redibujen. Ambos
                    // (semanal y "hoy") leen la misma instantánea.
                    try {
                        WeekWidgetReceiver.updateAll(applicationContext)
                        DayWidgetReceiver.updateAll(applicationContext)
                        result.success(null)
                    } catch (t: Throwable) {
                        result.error("widget_error", t.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
