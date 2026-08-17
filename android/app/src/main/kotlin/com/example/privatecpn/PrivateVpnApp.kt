package com.example.privatecpn

import android.app.Application
import com.example.privatecpn.vpn.WireGuardTunnelManager

/**
 * Custom Application class that holds a process-level singleton
 * WireGuardTunnelManager. This survives Activity recreation (e.g. when
 * the user swipes the app from recents and reopens it) so the GoBackend
 * instance and currentTunnel reference are never lost.
 */
class PrivateVpnApp : Application() {

    companion object {
        lateinit var tunnelManager: WireGuardTunnelManager
            private set
    }

    override fun onCreate() {
        super.onCreate()
        tunnelManager = WireGuardTunnelManager(applicationContext)
    }
}
