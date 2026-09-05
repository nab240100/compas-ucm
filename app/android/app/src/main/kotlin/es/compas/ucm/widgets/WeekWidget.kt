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
import es.compas.ucm.R
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

private const val PREFS_NAME = "FlutterSharedPreferences"
private const val SNAPSHOT_KEY = "flutter.widget_snapshot_v1"

private val TRANSPARENT = Color.TRANSPARENT
private val DEFAULT_FILL = Color.parseColor("#F5C8B0")
private val DEFAULT_ON = Color.parseColor("#5F2E1C")

/** Una celda (asignatura) de una fila del widget. */
private class Cell(
    val start: Int,
    val end: Int,
    val label: String,
    val group: String?,
    val fill: Int,
    val on: Int,
)

/** Una fila del widget: hora + 5 celdas (lunes..viernes). */
private class WeekRow(
    val startMinute: Int,
    val cells: Array<Cell?>, // índices 0..4 = lunes..viernes
)

private class WeekSnapshot(
    val semester: Int,
    val rows: List<WeekRow>,
)

private fun parseColor(raw: String, fallback: Int): Int = try {
    Color.parseColor(raw)
} catch (_: Exception) {
    fallback
}

private fun parseSnapshot(raw: String): WeekSnapshot {
    val root = JSONObject(raw)
    val semester = root.optInt("semester", 1)
    val daysArr = root.optJSONArray("days") ?: JSONArray()

    // Por día (0..4): la franja por minuto de inicio.
    val byDay = arrayOfNulls<Map<Int, Cell>>(5)
    for (i in 0 until daysArr.length()) {
        val d = daysArr.getJSONObject(i)
        val day = d.optInt("day") - 1
        if (day !in 0..4) continue
        val slots = d.optJSONArray("slots") ?: JSONArray()
        val map = HashMap<Int, Cell>()
        for (j in 0 until slots.length()) {
            val s = slots.getJSONObject(j)
            val start = s.optInt("start")
            if (map.containsKey(start)) continue
            val group = if (s.has("group") && !s.isNull("group")) {
                s.optString("group", "")
            } else {
                null
            }
            map[start] = Cell(
                start = start,
                end = s.optInt("end"),
                label = s.optString("label"),
                group = group,
                fill = parseColor(s.optString("color", ""), DEFAULT_FILL),
                on = parseColor(s.optString("on", ""), DEFAULT_ON),
            )
        }
        byDay[day] = map
    }

    // Grid horario fijo de 08:00 a 20:00 (una fila por hora, como el
    // horario de la app); cada celda muestra su rango exacto.
    val rows = ArrayList<WeekRow>(13)
    for (h in 8..20) {
        val cells = arrayOfNulls<Cell>(5)
        for (day in 0..4) {
            val map = byDay[day]
            cells[day] = map?.values?.firstOrNull { it.start / 60 == h }
        }
        rows.add(WeekRow(h * 60, cells))
    }
    return WeekSnapshot(semester, rows)
}

private fun loadSnapshot(context: Context): WeekSnapshot? {
    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    val raw = prefs.getString(SNAPSHOT_KEY, null) ?: return null
    return try {
        parseSnapshot(raw)
    } catch (_: Exception) {
        null
    }
}

private fun hhmm(minutes: Int): String {
    val h = minutes / 60
    val m = minutes % 60
    return if (m == 0) "$h:00" else "$h:${if (m < 10) "0$m" else m}"
}

private fun todayColumn(): Int {
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

/**
 * Widget de horario semanal: lee la instantánea que escribe la app en
 * SharedPreferences y muestra las filas L-V con las franjas del perfil.
 */
class WeekWidgetReceiver : AppWidgetProvider() {

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
        /** Redibuja todos los widgets tras guardar una nueva instantánea. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WeekWidgetReceiver::class.java),
            )
            for (id in ids) {
                render(context, manager, id)
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.week_widget)
            val snapshot = loadSnapshot(context)
            val empty = snapshot == null ||
                snapshot.rows.all { row -> row.cells.all { it == null } }

            views.setViewVisibility(R.id.week_list, if (empty) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.w_empty, if (empty) View.VISIBLE else View.GONE)

            if (!empty) {
                val s = snapshot!!
                views.setTextViewText(
                    R.id.w_title,
                    "Horario · ${if (s.semester == 1) "1Q" else "2Q"}",
                )
                val today = todayColumn()
                val letters = intArrayOf(
                    R.id.w_l1, R.id.w_l2, R.id.w_l3, R.id.w_l4, R.id.w_l5,
                )
                for (i in 0..4) {
                    views.setTextColor(
                        letters[i],
                        if (i == today) Color.parseColor("#B85C38")
                        else Color.parseColor("#7A6A58"),
                    )
                }
                val adapter = Intent(context, WeekWidgetService::class.java).apply {
                    data = Uri.parse("compas://widget/$id")
                }
                views.setRemoteAdapter(R.id.week_list, adapter)
            }

            // Tocar el widget abre la app.
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, es.compas.ucm.MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)

            manager.updateAppWidget(id, views)
        }
    }
}

/** Servicio que alimenta las filas de la lista del widget. */
class WeekWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WeekRowsFactory(applicationContext)
}

private class WeekRowsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var rows: List<WeekRow> = emptyList()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        rows = loadSnapshot(context)?.rows ?: emptyList()
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = rows[position]
        val views = RemoteViews(context.packageName, R.layout.week_widget_row)
        views.setTextViewText(R.id.w_time, hhmm(row.startMinute))
        val cells = intArrayOf(R.id.w_c1, R.id.w_c2, R.id.w_c3, R.id.w_c4, R.id.w_c5)
        for (i in 0..4) {
            val cell = row.cells[i]
            if (cell == null) {
                views.setTextViewText(cells[i], "")
                views.setInt(cells[i], "setBackgroundColor", TRANSPARENT)
            } else {
                // Línea 1: [grupo] asignatura · Línea 2: inicio-fin.
                val head = if (cell.group != null) "${cell.group} ${cell.label}"
                else cell.label
                val span = "${hhmm(cell.start)}-${hhmm(cell.end)}"
                views.setTextViewText(cells[i], "$head\n$span")
                views.setTextColor(cells[i], cell.on)
                views.setInt(cells[i], "setBackgroundColor", cell.fill)
            }
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
