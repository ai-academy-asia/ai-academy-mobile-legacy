package com.aiacademyasia.aia_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createDefaultNotificationChannel()
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
}
