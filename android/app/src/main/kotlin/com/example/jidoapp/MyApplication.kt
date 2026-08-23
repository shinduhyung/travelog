package com.example.jidoapp

import android.app.Application
import android.util.Log
import com.tiktok.TikTokBusinessSdk
import com.tiktok.TikTokBusinessSdk.TTConfig

class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        val ttConfig = TTConfig(
            applicationContext,
            "TTfB60TWFQLLj1HWEz8GxiautaIafB60"
        )
            .setAppId("com.ahnlee.jidoapp")
            .setTTAppId("7672457558463987732")

        TikTokBusinessSdk.initializeSdk(
            ttConfig,
            object : TikTokBusinessSdk.TTInitCallback {

                override fun success() {
                    Log.d(
                        "TikTokSDK",
                        "TikTok SDK initialized successfully"
                    )
                }

                override fun fail(code: Int, msg: String?) {
                    Log.e(
                        "TikTokSDK",
                        "TikTok SDK initialization failed: $code / $msg"
                    )
                }
            }
        )
    }
}