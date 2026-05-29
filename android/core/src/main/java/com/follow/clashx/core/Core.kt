package com.follow.clashx.core

import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URL

data object Core {
    private external fun startTun(
        fd: Int,
        cb: TunInterface
    )

    /**
     * Load libclash.so from the given path (or default search path if null).
     * Must be called BEFORE System.loadLibrary("core") / before init block runs.
     * Uses RTLD_GLOBAL so symbols are available to subsequently loaded libraries.
     */
    @JvmStatic
    external fun loadLibClash(path: String?): Boolean

    private fun parseInetSocketAddress(address: String): InetSocketAddress {
        val url = URL("https://$address")

        return InetSocketAddress(InetAddress.getByName(url.host), url.port)
    }

    fun startTun(
        fd: Int,
        protect: (Int) -> Boolean,
        resolverProcess: (protocol: Int, source: InetSocketAddress, target: InetSocketAddress, uid: Int) -> String
    ) {
        startTun(fd, object : TunInterface {
            override fun protect(fd: Int) {
                protect(fd)
            }

            override fun resolverProcess(
                protocol: Int,
                source: String,
                target: String,
                uid: Int
            ): String {
                return resolverProcess(
                    protocol,
                    parseInetSocketAddress(source),
                    parseInetSocketAddress(target),
                    uid,
                )
            }
        });
    }

    external fun stopTun()

    init {
        // loadLibClash() must be called externally before this object is first accessed.
        // It loads libclash.so into the process with RTLD_GLOBAL so that the symbols
        // (startTUN, stopTun, registerCallbacks, etc.) are available when libcore.so
        // is loaded below.
        System.loadLibrary("core")
    }
}
