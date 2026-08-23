package com.example.jidoapp

import android.util.Log
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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