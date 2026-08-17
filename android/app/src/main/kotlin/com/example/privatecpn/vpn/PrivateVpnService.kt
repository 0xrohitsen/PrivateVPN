package com.example.privatecpn.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.privatecpn.MainActivity
import com.example.privatecpn.R

class PrivateVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "com.example.privatecpn.vpn.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "com.example.privatecpn.vpn.ACTION_DISCONNECT"
        const val CHANNEL_ID = "private_vpn_channel"
        const val NOTIFICATION_ID = 1001

        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val serverName = intent.getStringExtra("server_name") ?: "Ubuntu VPS"
                val appCount = intent.getIntExtra("app_count", 0)
                startForeground(NOTIFICATION_ID, buildNotification(serverName, appCount))
                isRunning = true
            }
            ACTION_DISCONNECT -> {
                isRunning = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "PrivateVPN Status"
            val descriptionText = "Shows active WireGuard VPN tunnel status"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(serverName: String, appCount: String = ""): Notification {
        return buildNotification(serverName, if (appCount.isEmpty()) 0 else appCount.toIntOrNull() ?: 0)
    }

    private fun buildNotification(serverName: String, appCount: Int): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val contentText = if (appCount > 0) {
            "Connected to $serverName • $appCount apps routed"
        } else {
            "Connected to $serverName • All traffic routed"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PrivateVPN Active")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
