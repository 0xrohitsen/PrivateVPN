package com.example.privatecpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.annotation.NonNull
import com.example.privatecpn.apps.AppListProvider
import com.example.privatecpn.vpn.WireGuardTunnelManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.example.privatecpn/vpn_methods"
    private val EVENT_CHANNEL = "com.example.privatecpn/vpn_events"
    private val VPN_PREPARE_REQUEST_CODE = 1002

    // Reference to the Application-level singleton (never null after App.onCreate)
    private lateinit var tunnelManager: WireGuardTunnelManager
    private var vpnPermissionResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Use the Application-level singleton so the same GoBackend + tunnel
        // reference is reused when the Activity is recreated (e.g. swipe & reopen).
        tunnelManager = PrivateVpnApp.tunnelManager
        tunnelManager.setStateChangeListener { state ->
            scope.launch {
                eventSink?.success(state)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // Re-emit current state to Flutter immediately on reconnect
                    scope.launch {
                        val currentState = PrivateVpnApp.tunnelManager.getTunnelState()
                        eventSink?.success(currentState)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareVpn" -> {
                val intent = VpnService.prepare(this)
                if (intent != null) {
                    vpnPermissionResult = result
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, VPN_PREPARE_REQUEST_CODE)
                } else {
                    result.success(true)
                }
            }
            "startTunnel" -> {
                val config = call.argument<Map<String, Any?>>("config")
                val selectedApps = call.argument<List<String>>("selectedApps") ?: emptyList()

                if (config == null) {
                    result.error("INVALID_ARGS", "Configuration map is missing", null)
                    return
                }

                scope.launch {
                    val startRes = tunnelManager.startTunnel(config, selectedApps)
                    if (startRes.isSuccess) {
                        result.success(true)
                    } else {
                        result.error("VPN_ERROR", startRes.exceptionOrNull()?.message ?: "Failed to start VPN", null)
                    }
                }
            }
            "stopTunnel" -> {
                scope.launch {
                    val stopRes = tunnelManager.stopTunnel()
                    if (stopRes.isSuccess) {
                        result.success(true)
                    } else {
                        result.error("VPN_ERROR", stopRes.exceptionOrNull()?.message ?: "Failed to stop VPN", null)
                    }
                }
            }
            "getTunnelState" -> {
                scope.launch {
                    val state = tunnelManager.getTunnelState()
                    result.success(state)
                }
            }
            "getInstalledApps" -> {
                scope.launch {
                    try {
                        val apps = AppListProvider.getInstalledApps(applicationContext)
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("APP_LIST_ERROR", e.message, null)
                    }
                }
            }
            "generateKeyPair" -> {
                try {
                    val keys = tunnelManager.generateKeyPair()
                    result.success(keys)
                } catch (e: Exception) {
                    result.error("KEYGEN_ERROR", e.message, null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PREPARE_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            vpnPermissionResult?.success(granted)
            vpnPermissionResult = null
        }
    }
}
