package com.silifton.gyotaku

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {
    /**
     * The app runs in one engine that outlives this window.
     *
     * The reader lives in Dart. With the usual engine, one made for the
     * activity and destroyed with it, swiping the app out of the recent apps
     * list destroyed the reader mid-read, however much was left. An engine
     * handed over by the host is left alone when the activity goes, so the
     * reading carries on behind its notification, and the next window opened
     * finds the app as it was.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine = engine(context)

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        front = WeakReference(this)
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        if (front.get() === this) front = WeakReference(null)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ASK_NOTIFICATIONS) return
        val allowed = getSystemService(NotificationManager::class.java)
            ?.areNotificationsEnabled() == true
        // Android puts the question twice and after that answers no by
        // itself. It does not say which happened, but a no that comes back
        // faster than anyone could read a prompt means none was shown.
        val unasked = SystemClock.elapsedRealtime() - askedAt < NO_PROMPT_MS
        answer(if (allowed) "granted" else if (unasked) "unasked" else "denied")
    }

    companion object {
        private const val ENGINE = "gyotaku"
        private const val ASK_NOTIFICATIONS = 4107
        private const val NO_PROMPT_MS = 600L

        // The ask for notifications under way, if there is one, and when it
        // was put.
        private var asking: MethodChannel.Result? = null
        private var askedAt = 0L

        private fun answer(said: String) {
            asking?.success(said)
            asking = null
        }

        // The window on screen, if there is one, for the one thing that
        // needs it: asking for a permission.
        private var front = WeakReference<MainActivity>(null)

        fun engine(context: Context): FlutterEngine {
            FlutterEngineCache.getInstance().get(ENGINE)?.let { return it }
            val app = context.applicationContext
            val engine = FlutterEngine(app)
            channel(app, engine)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            FlutterEngineCache.getInstance().put(ENGINE, engine)
            return engine
        }

        // How the reader says what the notification should show, and how
        // Pause on the notification gets back to it. Set up with the engine,
        // not with a window, so it works when there is no window.
        private fun channel(app: Context, engine: FlutterEngine) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "gyotaku/scan")
            val main = Handler(Looper.getMainLooper())
            ScanService.onPause = { main.post { channel.invokeMethod("pause", null) } }
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> result.success(
                        ScanService.show(
                            app,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("text") ?: "",
                            call.argument<Int>("done") ?: 0,
                            call.argument<Int>("total") ?: 0,
                        ),
                    )
                    "finish" -> {
                        ScanService.finish(
                            app,
                            call.argument<String>("title"),
                            call.argument<String>("text"),
                        )
                        result.success(null)
                    }
                    // Whether a notification would be seen: the permission
                    // on Android 13 and later, and the switch in the
                    // system settings on every version.
                    "allowed" -> result.success(
                        app.getSystemService(NotificationManager::class.java)
                            ?.areNotificationsEnabled() ?: false,
                    )
                    // Puts Android's own question about notifications and
                    // says how it went: "granted", "denied", or "unasked"
                    // where there was no putting it. That is with no window
                    // to ask from, before Android 13, which has a switch in
                    // its settings and no prompt, and once Android has
                    // stopped asking.
                    "ask" -> {
                        val activity = front.get()
                        val allowed = app.getSystemService(NotificationManager::class.java)
                            ?.areNotificationsEnabled() == true
                        when {
                            allowed -> result.success("granted")
                            activity == null ||
                                Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED -> result.success("unasked")
                            else -> {
                                // An earlier ask that never heard back.
                                answer("denied")
                                asking = result
                                askedAt = SystemClock.elapsedRealtime()
                                activity.requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    ASK_NOTIFICATIONS,
                                )
                            }
                        }
                    }
                    // The page of the system's settings with this app's
                    // notification switch on it.
                    "settings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, app.packageName)
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", app.packageName, null),
                            )
                        }
                        try {
                            // From the window when there is one, so that
                            // Back from the settings comes back here and
                            // not to whatever the settings last showed.
                            val activity = front.get()
                            if (activity != null) {
                                activity.startActivity(intent)
                            } else {
                                app.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
