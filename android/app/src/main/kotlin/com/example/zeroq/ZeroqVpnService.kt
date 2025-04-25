package com.example.zeroq

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.sun.jna.Library
import com.sun.jna.Native
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.InetAddress
import kotlin.coroutines.resume

class ZeroqVpnService : VpnService() {

    enum class ZeroqState {
        INIT, STOPPED, STARTING, PREPARING, RUNNING
    }


    companion object {
        private var instance: ZeroqVpnService? = null
        private var state: ZeroqState = ZeroqState.INIT
        private val continuations = arrayListOf<CancellableContinuation<ZeroqVpnService>>()

        fun nullableInstance(): ZeroqVpnService? = instance

        suspend fun getInstance(context: Context): ZeroqVpnService {
            if (instance != null) return instance!!
            if (state <= ZeroqState.INIT) {
                state = ZeroqState.STARTING
                context.startService(Intent(context, ZeroqVpnService::class.java))
            }
            return suspendCancellableCoroutine {
                continuations.add(it)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        continuations.forEach {
            if (it.isActive) it.resume(this)
        }
        continuations.clear()
        LibAnyLink.INSTANCE.initLogger()
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        MainActivity.callbackWithKey("statusChanged", mapOf("connected" to false))
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tunRunUp: Job? = null

    fun startZeroQ(jsonArgs: String) {
        if (state >= ZeroqState.PREPARING) return
        state = ZeroqState.PREPARING
        var tunObject = JSONObject(LibAnyLink.INSTANCE.tunPrepare(jsonArgs))
        if (tunObject.getInt("code") != 0) {
            state = ZeroqState.STOPPED
            MainActivity.callbackWithKey(
                "statusChanged",
                mapOf("connected" to false, "msg" to tunObject.getString("msg"))
            )
            return
        }
        tunObject = JSONObject(tunObject.getString("msg"))
        tunFd = setupVpn(tunObject)
        tunRunUp = MainScope().launch {
            withContext(Dispatchers.IO) {
                tunFd?.let {
                    protect(it.fd)
                    val ret = LibAnyLink.INSTANCE.sslTunOn(it.fd)
                    if (ret != 0) {
                        state = ZeroqState.STOPPED
                        MainActivity.callbackWithKey(
                            "statusChanged",
                            mapOf("connected" to false, "msg" to "SSL TUN UP ERR")
                        )
                    } else {
                        state = ZeroqState.RUNNING
                        MainActivity.callbackWithKey("statusChanged", mapOf("connected" to true))
                    }
                }
            }
        }
    }

    private fun setupVpn(tunConfig: JSONObject): ParcelFileDescriptor? {
        val builder = Builder().addAddress(tunConfig.getString("VPNAddress"), tunConfig.getInt("VPNPrefix"))
            .setMtu(tunConfig.getInt("MTU"))
            .apply {
                addDisallowedApplication(packageName)
            }
            .allowBypass().setBlocking(true).setSession("ZeroQ").setConfigureIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent().setComponent(ComponentName(packageName, "$packageName.MainActivity")),
                    pendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT)
                )
            ).apply {
                if (Build.VERSION.SDK_INT >= 29) {
                    setMetered(false)
                }
            }
        tunConfig.optJSONArray("DNS")?.let {
            for (i in 0 until it.length()) {
                builder.addDnsServer(it[i] as String)
            }
        }
        if (tunConfig.isNull("SplitInclude")) {
            builder.addRoute("0.0.0.0", 0)
        } else {
            tunConfig.getJSONArray("SplitInclude").let {
                for (i in 0 until it.length()) {
                    (it[i] as String).split('/').let {
                        builder.addRoute(it[0], it[1].toInt())
                    }
                }
            }
        }
        if (Build.VERSION.SDK_INT > 32) {
            tunConfig.optJSONArray("SplitExclude")?.let { it ->
                for (i in 0 until it.length()) {
                    (it[i] as String).split('/').let {
                        builder.excludeRoute(IpPrefix(InetAddress.getByName(it[0]), it[1].toInt()))
                    }
                }
            }
            tunConfig.getString("ServerAddress").let { builder.excludeRoute(IpPrefix(InetAddress.getByName(it), 32)) }
        }
        return builder.establish()
    }


    private fun pendingIntentFlags(flags: Int, mutable: Boolean = false): Int {
        return if (Build.VERSION.SDK_INT >= 24) {
            if (Build.VERSION.SDK_INT > 30 && mutable) {
                flags or PendingIntent.FLAG_MUTABLE
            } else {
                flags or PendingIntent.FLAG_IMMUTABLE
            }
        } else {
            flags
        }
    }

    fun stopZeroq() {
        state != ZeroqState.RUNNING && return
        try {
            LibAnyLink.INSTANCE.vpnDisconnect()
        } catch (e: Exception) {
            e.message?.let { Log.e("anylink", it) }
        } finally {
            tunRunUp?.cancel()
            tunFd?.close()
            state = ZeroqState.STOPPED
            MainActivity.callbackWithKey("statusChanged", mapOf("connected" to false))
        }
    }

    fun status(): String? {
        if (state != ZeroqState.RUNNING) {
            return null
        }
        LibAnyLink.INSTANCE.vpnStatus().let {
            return it
        }
    }
}

interface LibAnyLink : Library {

    fun initLogger()
    fun tunPrepare(params: String): String
    fun sslTunOn(tunFd: Int): Int
    fun vpnDisconnect()
    fun vpnStatus(): String


    companion object {
        val INSTANCE = Native.load("anylink", LibAnyLink::class.java) as LibAnyLink
    }
}