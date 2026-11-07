package com.emprendesmart.app

import android.app.Notification
import android.content.Context
import android.content.pm.ApplicationInfo
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lee las notificaciones de Yape y de Plin (que llega por la app del banco: Interbank,
 * BBVA, Scotiabank, BanBif…) y guarda los pagos recibidos en una cola local.
 *
 * Android mantiene este servicio vivo aunque EmprendeSmart esté cerrada, así que
 * ningún cobro se pierde: la app Flutter lee la cola al abrirse (ver [YapeStore]).
 * El usuario debe habilitarlo en Ajustes > Acceso a notificaciones.
 */
class YapeNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // En builds de prueba también se aceptan los avisos publicados con
        // `adb shell cmd notification post` (paquete com.android.shell) para simular un Yape.
        val pkg = sbn.packageName
        if (pkg == packageName || pkg in MESSAGING_PACKAGES) return
        val isDebugBuild = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val isTestPost = isDebugBuild && pkg == "com.android.shell"

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val full = "$title $text"

        val source = when {
            pkg in YAPE_PACKAGES -> "yape"
            pkg in PLIN_BANK_PACKAGES || PLIN_WORD.containsMatchIn(full) -> "plin"
            isTestPost && YAPE_WORD.containsMatchIn(full) -> "yape"
            else -> return
        }

        // Solo los pagos que recibe el negocio (no promociones ni envíos propios) y con monto en soles.
        if (!RECEIVED_PAYMENT.containsMatchIn(full) || !AMOUNT.containsMatchIn(full)) return

        YapeStore.add(applicationContext, title, text, sbn.postTime, source)
    }

    companion object {
        val YAPE_PACKAGES = setOf("com.bcp.innovacxion.yapeapp")

        /** Apps de bancos que avisan los Plin recibidos. */
        val PLIN_BANK_PACKAGES = setOf(
            "pe.com.interbank.mobilebanking",
            "com.bbva.nxt_peru",
            "pe.com.scotiabank.blpm.android.client",
            "pe.com.banbif.mobilebanking",
        )

        /** Chats: un mensaje que diga "te envié un plin" no es un cobro real. */
        private val MESSAGING_PACKAGES = setOf(
            "com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger",
            "com.facebook.orca", "com.google.android.apps.messaging", "com.android.mms",
        )

        private val YAPE_WORD = Regex("yape", RegexOption.IGNORE_CASE)
        private val PLIN_WORD = Regex("\\bplin\\b", RegexOption.IGNORE_CASE)
        private val RECEIVED_PAYMENT = Regex(
            "te\\s+envi[oó]|recibiste|te\\s+(?:ha\\s+)?(?:pagado|transferido|yape[oó])|te\\s+plin(?:e[oó])?",
            RegexOption.IGNORE_CASE,
        )
        private val AMOUNT = Regex("S/\\.?\\s*\\d")
    }
}

/** Cola persistente (SharedPreferences) de notificaciones de Yape aún no leídas por Flutter. */
object YapeStore {
    const val PREFS = "emprende_smart_yape"
    const val KEY_QUEUE = "queue"
    private const val MAX_ITEMS = 300

    @Synchronized
    fun add(context: Context, title: String, text: String, postedAt: Long, source: String = "yape") {
        val queue = read(context)
        // La misma notificación puede publicarse dos veces (p. ej. al actualizarse): misma hora y texto.
        val id = "$postedAt-${text.hashCode()}"
        for (i in 0 until queue.length()) {
            if (queue.getJSONObject(i).optString("id") == id) return
        }
        queue.put(
            JSONObject()
                .put("id", id)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt)
                .put("source", source)
        )
        while (queue.length() > MAX_ITEMS) queue.remove(0)
        write(context, queue)
    }

    @Synchronized
    fun pending(context: Context): List<Map<String, Any>> {
        val queue = read(context)
        return (0 until queue.length()).map { i ->
            val item = queue.getJSONObject(i)
            mapOf(
                "id" to item.optString("id"),
                "title" to item.optString("title"),
                "text" to item.optString("text"),
                "postedAt" to item.optLong("postedAt"),
                "source" to item.optString("source", "yape"),
            )
        }
    }

    /** Borra de la cola los pagos que Flutter ya guardó. */
    @Synchronized
    fun ack(context: Context, ids: Collection<String>) {
        val queue = read(context)
        val kept = JSONArray()
        for (i in 0 until queue.length()) {
            val item = queue.getJSONObject(i)
            if (item.optString("id") !in ids) kept.put(item)
        }
        write(context, kept)
    }

    private fun read(context: Context): JSONArray {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_QUEUE, null)
        return try {
            if (raw == null) JSONArray() else JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun write(context: Context, queue: JSONArray) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_QUEUE, queue.toString()).apply()
    }
}
