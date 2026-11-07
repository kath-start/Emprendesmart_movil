package com.emprendesmart.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // SharedPreferences guarda los listeners con referencia débil: hay que retenerlo aquí.
    private var queueListener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "emprende_smart/yape").setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(isListenerEnabled())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                "pending" -> result.success(YapeStore.pending(applicationContext))
                "ack" -> {
                    YapeStore.ack(applicationContext, call.argument<List<String>>("ids") ?: emptyList())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Avisa a Flutter cuando llega un Yape con la app abierta, para mostrarlo al instante.
        EventChannel(messenger, "emprende_smart/yape_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val prefs = getSharedPreferences(YapeStore.PREFS, Context.MODE_PRIVATE)
                val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
                    if (key == YapeStore.KEY_QUEUE) runOnUiThread { events.success(null) }
                }
                queueListener = listener
                prefs.registerOnSharedPreferenceChangeListener(listener)
            }

            override fun onCancel(arguments: Any?) {
                queueListener?.let {
                    getSharedPreferences(YapeStore.PREFS, Context.MODE_PRIVATE).unregisterOnSharedPreferenceChangeListener(it)
                }
                queueListener = null
            }
        })
    }

    private fun isListenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val component = ComponentName(this, YapeNotificationListener::class.java)
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == component }
    }
}
