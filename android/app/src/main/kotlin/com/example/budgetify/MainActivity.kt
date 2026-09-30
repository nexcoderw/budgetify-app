package com.example.budgetify

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val USSD_CHANNEL =
            "budgetify/ussd"

        private const val SMS_CHANNEL =
            "budgetify/sms"

        private const val SMS_PERMISSION_REQUEST =
            4301
    }

    private var pendingSmsPermissionResult:
        MethodChannel.Result? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

        registerUssdChannel(
            flutterEngine
        )

        registerSmsChannel(
            flutterEngine
        )
    }

    private fun registerUssdChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            USSD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareUssd" ->
                    prepareUssd(result)

                "launchUssd" -> {
                    val code =
                        call.argument<String>(
                            "code"
                        )

                    launchUssd(
                        code = code,
                        result = result
                    )
                }

                else ->
                    result.notImplemented()
            }
        }
    }

    private fun registerSmsChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            SMS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" ->
                    result.success(
                        smsPermissionStatus()
                    )

                "requestPermission" ->
                    requestSmsPermission(
                        result
                    )

                "readRecentMomoMessages" ->
                    readRecentMomoMessages(
                        call = call,
                        result = result
                    )

                else ->
                    result.notImplemented()
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

    private fun smsPermissionStatus(): String {
        return if (hasSmsPermission()) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun hasSmsPermission(): Boolean {
        return checkSelfPermission(
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(
        result: MethodChannel.Result
    ) {
        if (hasSmsPermission()) {
            result.success("granted")
            return
        }

        if (pendingSmsPermissionResult != null) {
            result.error(
                "permission_in_progress",
                "SMS permission request is already in progress.",
                null
            )
            return
        }

        pendingSmsPermissionResult =
            result

        requestPermissions(
            arrayOf(
                Manifest.permission.READ_SMS
            ),
            SMS_PERMISSION_REQUEST
        )
    }

    private fun readRecentMomoMessages(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        if (!hasSmsPermission()) {
            result.error(
                "sms_permission_denied",
                "SMS access has not been granted.",
                null
            )
            return
        }

        val sinceMillis =
            call.argument<Number>(
                "sinceMillis"
            )?.toLong() ?: 0L

        val requestedLimit =
            call.argument<Int>(
                "limit"
            ) ?: 100

        val limit =
            requestedLimit.coerceIn(
                1,
                200
            )

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )

        val messages =
            mutableListOf<
                Map<String, Any?>
            >()

        try {
            contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                projection,
                "${Telephony.Sms.DATE} >= ?",
                arrayOf(
                    sinceMillis.toString()
                ),
                "${Telephony.Sms.DATE} DESC"
            )?.use { cursor ->
                val idIndex =
                    cursor.getColumnIndexOrThrow(
                        Telephony.Sms._ID
                    )

                val addressIndex =
                    cursor.getColumnIndexOrThrow(
                        Telephony.Sms.ADDRESS
                    )

                val bodyIndex =
                    cursor.getColumnIndexOrThrow(
                        Telephony.Sms.BODY
                    )

                val dateIndex =
                    cursor.getColumnIndexOrThrow(
                        Telephony.Sms.DATE
                    )

                while (
                    cursor.moveToNext() &&
                    messages.size < limit
                ) {
                    val id =
                        cursor.getLong(
                            idIndex
                        )
                            .toString()

                    val address =
                        cursor.getString(
                            addressIndex
                        ) ?: ""

                    val body =
                        cursor.getString(
                            bodyIndex
                        ) ?: ""

                    val receivedAtMillis =
                        cursor.getLong(
                            dateIndex
                        )

                    if (
                        !isPotentialMomoMessage(
                            address = address,
                            body = body
                        )
                    ) {
                        continue
                    }

                    messages.add(
                        mapOf(
                            "id" to id,
                            "address" to address,
                            "body" to body,
                            "receivedAtMillis" to
                                receivedAtMillis
                        )
                    )
                }
            }

            result.success(messages)
        } catch (error: SecurityException) {
            result.error(
                "sms_permission_denied",
                "SMS access has not been granted.",
                null
            )
        } catch (error: Exception) {
            result.error(
                "sms_read_failed",
                "Could not read recent transaction messages.",
                null
            )
        }
    }

    private fun isPotentialMomoMessage(
        address: String,
        body: String
    ): Boolean {
        val sender =
            address.lowercase()

        val text =
            body.lowercase()

        if (!text.contains("rwf")) {
            return false
        }

        val senderMatches =
            sender.contains("mtn") ||
            sender.contains("momo") ||
            sender.contains("m-money") ||
            sender.contains("mobilemoney")

        val bodyMatches =
            text.contains("mobile money") ||
            text.contains("momo") ||
            text.contains(
                "financial transaction id"
            )

        return senderMatches ||
            bodyMatches
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (
            requestCode ==
            SMS_PERMISSION_REQUEST
        ) {
            val granted =
                grantResults.isNotEmpty() &&
                grantResults[0] ==
                PackageManager.PERMISSION_GRANTED

            pendingSmsPermissionResult
                ?.success(
                    if (granted) {
                        "granted"
                    } else {
                        "denied"
                    }
                )

            pendingSmsPermissionResult =
                null

            return
        }

        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )
    }
}