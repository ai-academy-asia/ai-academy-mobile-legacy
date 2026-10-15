package com.aiacademyasia.aia_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> result.success(openNotificationSettings())
                    "isDefaultChannelBlocked" -> result.success(isDefaultChannelBlocked())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the user blocked the default channel, "Мэдэгдэл" (Issue #433).
     * Firebase reports only the app-level permission, yet posts every push
     * into this channel — blocked, pushes arrive and are never shown. Only
     * read, never changed. False below API 26 (no channels) and when the
     * channel does not exist yet; Firebase then shows pushes in its fallback.
     */
    private fun isDefaultChannelBlocked(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(NotificationManager::class.java) ?: return false
        val channel =
            manager.getNotificationChannel(getString(R.string.default_notification_channel_id))
                ?: return false
        return channel.importance == NotificationManager.IMPORTANCE_NONE
    }

    /**
     * Opens this app's notification settings (Issue #429) — the Profile
     * Notification switch's tap; only there can a refused permission be
     * changed. API 26+ has a screen for exactly that; below it, the app's
     * details screen, where notifications are one row. False when nothing
     * could open it.
     */
    private fun openNotificationSettings(): Boolean {
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                )
            }
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * The channel Firebase posts notification messages to (Issue #425), named
     * in the manifest's `default_notification_channel_id`.
     *
     * Here rather than in an Application subclass: a push only reaches a device
     * whose token was registered after sign-in, which runs through this
     * activity, and Android keeps a channel once created. Safe on every start:
     * creating an existing channel only refreshes its name, never the
     * importance or sound the user has since changed. Channels exist from
     * API 26; below that (minSdk is 24) there is nothing to create.
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                getString(R.string.default_notification_channel_id),
                getString(R.string.default_notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    private companion object {
        /** Named in Dart's notification_settings_opener.dart; a test pins both. */
        const val NOTIFICATION_SETTINGS_CHANNEL = "com.aiacademyasia.aia_mobile/notification_settings"
    }
}
