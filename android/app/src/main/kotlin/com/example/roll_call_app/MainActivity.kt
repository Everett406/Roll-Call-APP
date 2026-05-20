package com.example.roll_call_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    // Enable predictive back gesture for Android 14+
    override fun getBackGestureEnabled(): Boolean = true
}
