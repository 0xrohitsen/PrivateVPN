package com.example.privatecpn.vpn

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayInputStream
import java.net.InetAddress

class WireGuardTunnelManager(private val context: Context) {

    private val TAG = "WireGuardTunnelManager"
    private val TUNNEL_NAME = "PrivateVPN"
    private var backend: Backend? = null
    private var currentTunnel: CustomTunnel? = null
    private var stateChangeListener: ((String) -> Unit)? = null

    class CustomTunnel(private val name: String, private val onStateChanged: (Tunnel.State) -> Unit) : Tunnel {
        override fun getName(): String = name
        override fun onStateChange(state: Tunnel.State) {
            onStateChanged(state)
        }
    }

    fun setStateChangeListener(listener: (String) -> Unit) {
        this.stateChangeListener = listener
    }

    private suspend fun getBackend(): Backend = withContext(Dispatchers.IO) {
        if (backend == null) {
            backend = GoBackend(context)
        }
        backend!!
    }

    suspend fun startTunnel(
        configData: Map<String, Any?>,
        selectedApps: List<String>
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val backendInstance = getBackend()

            val privateKeyStr = configData["clientPrivateKey"] as? String ?: ""
            val clientAddressStr = configData["clientAddress"] as? String ?: "10.8.0.2/32"
            val serverPublicKeyStr = configData["serverPublicKey"] as? String ?: ""
            val serverEndpointStr = configData["serverEndpoint"] as? String ?: ""
            val dnsStr = configData["dns"] as? String ?: "1.1.1.1"
            val serverName = configData["serverName"] as? String ?: "Ubuntu VPS"

            if (privateKeyStr.isBlank() || serverPublicKeyStr.isBlank() || serverEndpointStr.isBlank()) {
                return@withContext Result.failure(IllegalArgumentException("Missing required WireGuard configuration parameters"))
            }

            // Build WireGuard configuration string
            val configStringBuilder = StringBuilder()
            configStringBuilder.append("[Interface]\n")
            configStringBuilder.append("PrivateKey = ").append(privateKeyStr.trim()).append("\n")
            configStringBuilder.append("Address = ").append(clientAddressStr.trim()).append("\n")
            if (dnsStr.isNotBlank()) {
                configStringBuilder.append("DNS = ").append(dnsStr.trim()).append("\n")
            }

            // Per-App Routing allowlist
            if (selectedApps.isNotEmpty()) {
                configStringBuilder.append("IncludedApplications = ")
                    .append(selectedApps.joinToString(", "))
                    .append("\n")
            }

            configStringBuilder.append("\n[Peer]\n")
            configStringBuilder.append("PublicKey = ").append(serverPublicKeyStr.trim()).append("\n")
            configStringBuilder.append("Endpoint = ").append(serverEndpointStr.trim()).append("\n")
            configStringBuilder.append("AllowedIPs = 0.0.0.0/0, ::/0\n")
            configStringBuilder.append("PersistentKeepalive = 25\n")

            val configString = configStringBuilder.toString()
            val config = Config.parse(ByteArrayInputStream(configString.toByteArray(Charsets.UTF_8)))

            val tunnel = currentTunnel ?: CustomTunnel(TUNNEL_NAME) { newState ->
                val stateName = when (newState) {
                    Tunnel.State.UP -> "connected"
                    Tunnel.State.DOWN -> "disconnected"
                    Tunnel.State.TOGGLE -> "connecting"
                }
                stateChangeListener?.invoke(stateName)
            }.also { currentTunnel = it }

            // If already up, turn down first before reapplying
            try {
                if (backendInstance.getState(tunnel) == Tunnel.State.UP) {
                    backendInstance.setState(tunnel, Tunnel.State.DOWN, null)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error resetting tunnel state: ${e.message}")
            }

            // Start foreground service notification
            val serviceIntent = Intent(context, PrivateVpnService::class.java).apply {
                action = PrivateVpnService.ACTION_CONNECT
                putExtra("server_name", serverName)
                putExtra("app_count", selectedApps.size)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            backendInstance.setState(tunnel, Tunnel.State.UP, config)
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start WireGuard tunnel", e)
            stopForegroundService()
            Result.failure(e)
        }
    }

    suspend fun stopTunnel(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val backendInstance = getBackend()
            currentTunnel?.let { tunnel ->
                try {
                    backendInstance.setState(tunnel, Tunnel.State.DOWN, null)
                } catch (e: Exception) {
                    Log.w(TAG, "Error stopping tunnel backend: ${e.message}")
                }
            }
            stopForegroundService()
            stateChangeListener?.invoke("disconnected")
            Result.success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop WireGuard tunnel", e)
            stopForegroundService()
            Result.failure(e)
        }
    }

    /**
     * Recovers the tunnel reference after an app restart.
     * WireGuard GoBackend keeps the tunnel alive even when the app is killed.
     * We probe the known tunnel name to check if it's still up.
     */
    private suspend fun recoverTunnel(backendInstance: Backend): CustomTunnel {
        // Return existing reference if we have one
        currentTunnel?.let { return it }

        // Create a probe tunnel with the known name and check its state
        val probeTunnel = CustomTunnel(TUNNEL_NAME) { newState ->
            val stateName = when (newState) {
                Tunnel.State.UP -> "connected"
                Tunnel.State.DOWN -> "disconnected"
                Tunnel.State.TOGGLE -> "connecting"
            }
            stateChangeListener?.invoke(stateName)
        }

        return try {
            val state = backendInstance.getState(probeTunnel)
            if (state == Tunnel.State.UP) {
                // Tunnel is alive — restore reference so future calls work
                Log.i(TAG, "Recovered running tunnel after app restart")
                currentTunnel = probeTunnel
            }
            probeTunnel
        } catch (e: Exception) {
            Log.w(TAG, "Tunnel probe failed (expected if never connected): ${e.message}")
            probeTunnel
        }
    }

    suspend fun getTunnelState(): String = withContext(Dispatchers.IO) {
        try {
            val backendInstance = getBackend()
            val tunnel = recoverTunnel(backendInstance)
            when (backendInstance.getState(tunnel)) {
                Tunnel.State.UP -> "connected"
                Tunnel.State.DOWN -> "disconnected"
                Tunnel.State.TOGGLE -> "connecting"
            }
        } catch (e: Exception) {
            Log.w(TAG, "getTunnelState failed: ${e.message}")
            "disconnected"
        }
    }

    private fun stopForegroundService() {
        try {
            val serviceIntent = Intent(context, PrivateVpnService::class.java).apply {
                action = PrivateVpnService.ACTION_DISCONNECT
            }
            context.startService(serviceIntent)
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping foreground service: ${e.message}")
        }
    }

    fun generateKeyPair(): Map<String, String> {
        val keyPair = KeyPair()
        return mapOf(
            "privateKey" to keyPair.privateKey.toBase64(),
            "publicKey" to keyPair.publicKey.toBase64()
        )
    }
}
