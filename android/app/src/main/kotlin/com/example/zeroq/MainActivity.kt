package com.example.zeroq

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.JSONUtil
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import org.jetbrains.annotations.NotNull
import kotlin.coroutines.resume

private const val ACTION_PREPARE_VPN = 0xF1

class MainActivity : FlutterActivity() {

    private val scope = MainScope()
    private var vpnPreparing: CancellableContinuation<Boolean>? = null

    override fun configureFlutterEngine(@NotNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    zeroqVpnServiceScope(result) {
                        val prepared = prepareVpn()
                        if (!prepared) {
                            result.success(false)
                            return@zeroqVpnServiceScope
                        }
                        val args = call.arguments<Map<String, Any>>()
                        it.startZeroQ(JSONUtil.wrap(args).toString())
                    }
                }
                "stopVpn" -> {
                    zeroqVpnServiceScope(result) {
                        it.stopZeroq()
                        result.success(null)
                    }
                }
                "status" -> {
                    nullableZeroqVpnServiceScope(result) {
                        val stats = it?.status()
                        result.success(stats ?: "{}")
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.zeroq.demo/vpn"
        private lateinit var channel: MethodChannel
        fun callbackWithKey(callbackKey: String, params: Map<String, Any>?) {
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod(callbackKey, params)
            }
        }
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == ACTION_PREPARE_VPN) {
            if (scope.isActive && vpnPreparing?.isActive == true) {
                vpnPreparing?.resume(resultCode == Activity.RESULT_OK)
            }
        }
    }

    private suspend fun prepareVpn(): Boolean {
        val prepareIntent = VpnService.prepare(activity) ?: return true
        activity.startActivityForResult(prepareIntent, ACTION_PREPARE_VPN)
        return suspendCancellableCoroutine {
            vpnPreparing = it
        }
    }

    private fun zeroqVpnServiceScope(
        result: Result,
        withService: suspend CoroutineScope.(ZeroqVpnService) -> Unit,
    ) {
        val activity = this.activity
        scope.launch {
            withService.invoke(this, ZeroqVpnService.getInstance(activity))
        }
    }

    private fun nullableZeroqVpnServiceScope(
        result: Result,
        withService: suspend CoroutineScope.(ZeroqVpnService?) -> Unit
    ) {
        scope.launch {
            withService.invoke(this, ZeroqVpnService.nullableInstance())
        }
    }
}
