package es.compas.ucm.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.compas.ucm.MainActivity
import es.compas.ucm.R
import java.util.Calendar
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

private const val DAY_PREFS_NAME = "FlutterSharedPreferences"
private const val DAY_SNAPSHOT_KEY = "flutter.widget_snapshot_v1"

private const val DAY_FILL = "#F5C8B0"
private const val DAY_ON = "#5F2E1C"

/** Una clase del día, lista para pintar en el widget. */
private class DayCell(
    val start: Int,
    val end: Int,
    val label: String,
    val group: String?,
    val fill: Int,
    val on: Int,
)

/** Instantánea del horario: semestre + clases de cada día (índice 0..4 = L..V). */
private class DaySnapshot(
    val semester: Int,
    val cellsByDay: Array<List<DayCell>>,
)

// Colores de la paleta de asignaturas (CoursePalette.dart): orden fijo.
// Cada color tiene su tarjeta redondeada day_cell_N (res/drawable).
private val FILL_COLORS = intArrayOf(
    Color.parseColor("#F5C8B0"), Color.parseColor("#DDE7C0"), Color.parseColor("#FBDC9E"),
    Color.parseColor("#C9DDF0"), Color.parseColor("#E4D3F5"), Color.parseColor("#F6CBD4"),
    Color.parseColor("#CFEBDD"), Color.parseColor("#F2DCC0"), Color.parseColor("#D3E2ED"),
    Color.parseColor("#FAD5B8"), Color.parseColor("#D6E3C8"), Color.parseColor("#EFD0E4"),
)
private val CARD_DRAWS = intArrayOf(
    R.drawable.day_cell_0, R.drawable.day_cell_1, R.drawable.day_cell_2,
    R.drawable.day_cell_3, R.drawable.day_cell_4, R.drawable.day_cell_5,
    R.drawable.day_cell_6, R.drawable.day_cell_7, R.drawable.day_cell_8,
    R.drawable.day_cell_9, R.drawable.day_cell_10, R.drawable.day_cell_11,
)

/** Tarjeta redondeada cuyo color coincide con [fill]; por defecto la primera. */
private fun cardDrawableFor(fill: Int): Int {
    for (i in FILL_COLORS.indices) {
        if (FILL_COLORS[i] == fill) return CARD_DRAWS[i]
    }
    return CARD_DRAWS[0]
}

private fun dayColor(raw: String, fallback: Int): Int = try {
    Color.parseColor(raw)
} catch (_: Exception) {
    fallback
}

private fun loadDaySnapshot(context: Context): DaySnapshot? {
    val prefs = context.getSharedPreferences(DAY_PREFS_NAME, Context.MODE_PRIVATE)
    val raw = prefs.getString(DAY_SNAPSHOT_KEY, null) ?: return null
    return try {
        val root = JSONObject(raw)
        val semester = root.optInt("semester", 1)
        val daysArr = root.optJSONArray("days") ?: JSONArray()
        val cellsByDay = arrayOfNulls<List<DayCell>>(5)
        for (i in 0 until daysArr.length()) {
            val d = daysArr.getJSONObject(i)
            val day = d.optInt("day") - 1
            if (day !in 0..4) continue
            val slots = d.optJSONArray("slots") ?: JSONArray()
            val cells = ArrayList<DayCell>(6)
            for (j in 0 until slots.length()) {
                val s = slots.getJSONObject(j)
                val group = if (s.has("group") && !s.isNull("group")) {
                    s.optString("group", "")
                } else {
                    null
                }
                cells.add(
                    DayCell(
                        start = s.optInt("start"),
                        end = s.optInt("end"),
                        label = s.optString("label"),
                        group = group,
                        fill = dayColor(s.optString("color", ""), Color.parseColor(DAY_FILL)),
                        on = dayColor(s.optString("on", ""), Color.parseColor(DAY_ON)),
                    ),
                )
            }
            cells.sortBy { it.start }
            cellsByDay[day] = cells
        }
        DaySnapshot(semester, cellsByDay.map { it ?: emptyList() }.toTypedArray())
    } catch (_: Exception) {
        null
    }
}

/** Columna de hoy (0..4 = lunes..viernes) o -1 en fin de semana. */
private fun todayDayColumn(): Int {
    val dow = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
    return when (dow) {
        Calendar.MONDAY -> 0
        Calendar.TUESDAY -> 1
        Calendar.WEDNESDAY -> 2
        Calendar.THURSDAY -> 3
        Calendar.FRIDAY -> 4
        else -> -1
    }
}

private fun dayHhmm(minutes: Int): String {
    val h = minutes / 60
    val m = minutes % 60
    return if (m == 0) "$h:00" else "$h:${if (m < 10) "0$m" else m}"
}

private val WEEKDAYS = arrayOf("lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo")
private val MONTHS = arrayOf(
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
)

/** Nombre del día de [calendar] en minúsculas (p. ej. "viernes"). */
private fun weekdayName(calendar: Calendar): String {
    val idx = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7
    return WEEKDAYS[idx]
}

/** Fecha de hoy como "4 de septiembre". */
private fun dateLabel(calendar: Calendar): String {
    val month = MONTHS[calendar.get(Calendar.MONTH)]
    return "${calendar.get(Calendar.DAY_OF_MONTH)} de $month"
}

/**
 * Widget "Horario de hoy": lee la misma instantánea que el widget semanal y
 * muestra las clases del día como tarjetas redondeadas (agenda). En fin de
 * semana o sin clases muestra un mensaje tranquilo.
 */
class DayWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id)
        }
    }

    companion object {
        /** Redibuja todos los widgets "de hoy" (tras guardar la instantánea). */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, DayWidgetReceiver::class.java),
            )
            for (id in ids) {
                render(context, manager, id)
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.day_widget)
            val snapshot = loadDaySnapshot(context)
            val col = todayDayColumn()
            val today = Calendar.getInstance()
            val cells = if (snapshot != null && col in 0..4) snapshot.cellsByDay[col] else emptyList()
            val hasClasses = cells.isNotEmpty()

            // Cabecera al estilo del widget de Google Calendar: día en
            // versalitas (nunca se corta) + fecha grande debajo.
            views.setTextViewText(R.id.d_day, weekdayName(today).uppercase(Locale.ROOT))
            views.setTextViewText(R.id.d_date, dateLabel(today))

            if (snapshot != null && hasClasses) {
                val count = cells.size
                val tag = semesterTag(snapshot.semester)
                val meta = "$tag · " + if (count == 1) "1 clase" else "$count clases"
                views.setTextViewText(R.id.d_meta, meta)
                views.setViewVisibility(R.id.d_meta, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.d_meta, "")
                views.setViewVisibility(R.id.d_meta, View.GONE)
            }

            views.setViewVisibility(R.id.day_list, if (hasClasses) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.d_empty, if (hasClasses) View.GONE else View.VISIBLE)

            if (hasClasses) {
                val adapter = Intent(context, DayWidgetService::class.java).apply {
                    data = Uri.parse("compas://daywidget/$id")
                }
                views.setRemoteAdapter(R.id.day_list, adapter)
            } else {
                val message = if (snapshot == null) {
                    "Abre Compás UCM para generar tu horario."
                } else {
                    "No hay clases hoy."
                }
                views.setTextViewText(R.id.d_empty, message)
            }

            // Tocar el widget abre la app.
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.day_root, open)

            manager.updateAppWidget(id, views)
        }

        private fun semesterTag(semester: Int): String =
            if (semester == 1) "1Q" else "2Q"
    }
}

/** Servicio que alimenta las tarjetas de la lista del widget de hoy. */
class DayWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        DayRowsFactory(applicationContext)
}

private class DayRowsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var cells: List<DayCell> = emptyList()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        val col = todayDayColumn()
        cells = if (col in 0..4) loadDaySnapshot(context)?.cellsByDay?.get(col) ?: emptyList()
        else emptyList()
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = cells.size

    override fun getViewAt(position: Int): RemoteViews {
        val cell = cells[position]
        val views = RemoteViews(context.packageName, R.layout.day_widget_row)

        // Hora y grupo dentro de la propia tarjeta.
        val span = "${dayHhmm(cell.start)}–${dayHhmm(cell.end)}"
        val hasGroup = cell.group != null && cell.group.isNotEmpty()
        views.setTextViewText(
            R.id.d_sub,
            if (hasGroup) "$span · ${cell.group}" else span,
        )

        views.setTextViewText(R.id.d_label, cell.label)
        views.setTextColor(R.id.d_label, cell.on)
        // La línea de hora/grupo va algo más suave (mismo color con alpha).
        val subColor = Color.argb(
            0xCC,
            Color.red(cell.on),
            Color.green(cell.on),
            Color.blue(cell.on),
        )
        views.setTextColor(R.id.d_sub, subColor)
        views.setInt(R.id.d_card, "setBackgroundResource", cardDrawableFor(cell.fill))
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
