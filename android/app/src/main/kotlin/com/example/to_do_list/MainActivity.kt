package com.example.to_do_list // Make sure this matches your actual package name!

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.util.Log
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.todo/speech"
    private var speechRecognizer: SpeechRecognizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    startOfflineSpeechRecognition(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startOfflineSpeechRecognition(result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("UNAVAILABLE", "Speech recognition not available on this device.", null)
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            // THIS IS THE MAGIC FLAG FOR OFFLINE AI:
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true) 
        }

        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            
            override fun onError(error: Int) {
                result.error("SPEECH_ERROR", "Error code: $error", null)
                speechRecognizer?.destroy()
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    result.success(matches[0]) // Send the best text match back to Flutter
                } else {
                    result.error("NO_MATCH", "No speech recognized.", null)
                }
                speechRecognizer?.destroy()
            }

            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer?.startListening(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
    }
}