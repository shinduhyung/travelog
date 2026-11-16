package com.example.jidoapp

import android.util.Log
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.tiktok.TikTokBusinessSdk
import com.tiktok.appevents.contents.TTContentParams
import com.tiktok.appevents.contents.TTContentsEventConstants
import com.tiktok.appevents.contents.TTPurchaseEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.ahnlee.jidoapp/tiktok_events"
        private const val TAG = "TikTokPurchase"
        private const val REFERRER_CHANNEL = "com.ahnlee.jidoapp/install_referrer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Play 설치 리퍼러: 어떤 광고(구글 gclid, 메타 utm_content 등)로 설치됐는지 남기기 위함
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REFERRER_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method != "getInstallReferrer") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            var replied = false
            fun reply(value: Map<String, Any?>?) {
                if (replied) return
                replied = true
                runOnUiThread { result.success(value) }
            }
            try {
                val client = InstallReferrerClient.newBuilder(applicationContext).build()
                client.startConnection(object : InstallReferrerStateListener {
                    override fun onInstallReferrerSetupFinished(responseCode: Int) {
                        try {
                            if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                                val d = client.installReferrer
                                reply(
                                    mapOf(
                                        "referrer" to d.installReferrer,
                                        "clickTs" to d.referrerClickTimestampSeconds,
                                        "installTs" to d.installBeginTimestampSeconds,
                                        "instantExperience" to d.googlePlayInstantParam
                                    )
                                )
                            } else {
                                reply(mapOf("error" to "response_$responseCode"))
                            }
                        } catch (e: Exception) {
                            reply(mapOf("error" to (e.message ?: "exception")))
                        } finally {
                            try { client.endConnection() } catch (_: Exception) {}
                        }
                    }

                    override fun onInstallReferrerServiceDisconnected() {
                        reply(mapOf("error" to "disconnected"))
                    }
                })
            } catch (e: Exception) {
                reply(mapOf("error" to (e.message ?: "exception")))
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "trackPurchase" -> {
                    try {
                        val value =
                            (call.argument<Number>("value"))?.toDouble() ?: 0.0

                        val currencyCode =
                            call.argument<String>("currency")
                                ?.uppercase(Locale.US)
                                ?: "USD"

                        val productId =
                            call.argument<String>("productId")
                                ?: "travelog_premium_yearly"

                        val currency = try {
                            TTContentsEventConstants.Currency.valueOf(
                                currencyCode
                            )
                        } catch (e: IllegalArgumentException) {
                            Log.w(
                                TAG,
                                "Unsupported currency: $currencyCode. Falling back to USD."
                            )

                            TTContentsEventConstants.Currency.USD
                        }

                        val content = TTContentParams
                            .newBuilder()
                            .setContentId(productId)
                            .setContentCategory("subscription")
                            .setContentName("Travelog Premium Yearly")
                            .setPrice(value.toFloat())
                            .setQuantity(1)
                            .build()

                        val event = TTPurchaseEvent
                            .newBuilder()
                            .setDescription(
                                "Travelog Premium yearly subscription"
                            )
                            .setCurrency(currency)
                            .setValue(value)
                            .setContents(content)
                            .setContentType("product")
                            .build()

                        TikTokBusinessSdk.trackTTEvent(event)

                        // 바로 전송을 시도하도록 flush
                        TikTokBusinessSdk.flush()

                        Log.d(
                            TAG,
                            "Purchase sent: $value $currencyCode / $productId"
                        )

                        result.success(true)

                    } catch (e: Exception) {

                        Log.e(
                            TAG,
                            "Failed to send TikTok Purchase",
                            e
                        )

                        result.error(
                            "TIKTOK_PURCHASE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}