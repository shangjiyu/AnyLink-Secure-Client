package com.example.zeroq

import android.content.Intent
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.JSONUtil
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

private const val ACTION_PREPARE_VPN = 0xF1

class MainActivity : FlutterFragmentActivity() {

    private val scope = MainScope()
    private var vpnPreparing: CancellableContinuation<Boolean>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ACTION_PREPARE_VPN) {
            if (scope.isActive && vpnPreparing?.isActive == true) {
                vpnPreparing?.resume(resultCode == RESULT_OK)
            }
        }
    }

    private suspend fun prepareVpn(): Boolean {
        val prepareIntent = VpnService.prepare(this) ?: return true
        this.startActivityForResult(prepareIntent, ACTION_PREPARE_VPN)
        return suspendCancellableCoroutine {
            vpnPreparing = it
        }
    }

    private fun zeroqVpnServiceScope(
        result: Result,
        withService: suspend CoroutineScope.(ZeroqVpnService) -> Unit,
    ) {
        scope.launch {
            withService.invoke(this, ZeroqVpnService.getInstance(this@MainActivity))
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
