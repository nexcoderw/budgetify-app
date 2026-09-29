package com.example.budgetify

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "budgetify/ussd"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareUssd" -> prepareUssd(result)

                "launchUssd" -> {
                    val code = call.argument<String>("code")

                    launchUssd(
                        code = code,
                        result = result
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun prepareUssd(
        result: MethodChannel.Result
    ) {
        result.success(true)
    }

    private fun launchUssd(
        code: String?,
        result: MethodChannel.Result
    ) {
        if (
            code.isNullOrBlank() ||
            !code.startsWith("*182*") ||
            !code.endsWith("#")
        ) {
            result.error(
                "invalid_ussd",
                "Invalid MTN USSD command.",
                null
            )
            return
        }

        val uri = Uri.fromParts(
            "tel",
            code,
            null
        )

        val intent = Intent(
            Intent.ACTION_DIAL,
            uri
        )

        try {
            startActivity(intent)
            result.success(null)
        } catch (
            error: ActivityNotFoundException
        ) {
            result.error(
                "phone_unavailable",
                "No phone application is available to process the USSD request.",
                null
            )
        } catch (error: Exception) {
            result.error(
                "ussd_failed",
                "Could not open the MTN USSD request.",
                null
            )
        }
    }

}
