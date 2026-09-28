package com.example.budgetify

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "budgetify/ussd"
        private const val CALL_PERMISSION_REQUEST = 4201
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

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
        if (hasCallPermission()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "permission_in_progress",
                "Phone permission request is already in progress.",
                null
            )
            return
        }

        pendingPermissionResult = result

        requestPermissions(
            arrayOf(Manifest.permission.CALL_PHONE),
            CALL_PERMISSION_REQUEST
        )
    }

    private fun launchUssd(
        code: String?,
        result: MethodChannel.Result
    ) {
        if (!hasCallPermission()) {
            result.error(
                "permission_denied",
                "Phone permission is required to open the USSD transfer.",
                null
            )
            return
        }

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
            Intent.ACTION_CALL,
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
        } catch (error: SecurityException) {
            result.error(
                "permission_denied",
                "Phone permission was not granted.",
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

    private fun hasCallPermission(): Boolean {
        if (
            Build.VERSION.SDK_INT <
            Build.VERSION_CODES.M
        ) {
            return true
        }

        return checkSelfPermission(
            Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (
            requestCode ==
            CALL_PERMISSION_REQUEST
        ) {
            val granted =
                grantResults.isNotEmpty() &&
                grantResults[0] ==
                PackageManager.PERMISSION_GRANTED

            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null

            return
        }

        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )
    }
}
