package com.matteonoris.app4athletes

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.4athletes.health/hrv"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getRRIntervals") {
                // TODO: Implementazione Health Connect per leggere HeartRateVariabilityRmssdRecord
                // Per ora ritorniamo una lista vuota in attesa dell'integrazione SDK Health Connect
                result.success(emptyList<Double>())
            } else {
                result.notImplemented()
            }
        }
    }
}
