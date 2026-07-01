import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomsheet.BottomSheetBehavior

class MainActivity : FlutterActivity() {

    private lateinit var bottomSheetBehavior: BottomSheetBehavior<LinearLayout>
    private var backPressedTime: Long = 0
    private val LONG_PRESS_THRESHOLD = 500L // Time in ms

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val bottomSheet = findViewById<LinearLayout>(R.id.gemini_bottom_sheet)
        bottomSheetBehavior = BottomSheetBehavior.from(bottomSheet)
        
        // Ensure sheet is hidden initially
        bottomSheetBehavior.state = BottomSheetBehavior.STATE_HIDDEN
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            // Start the timer on the very first press down
            if (event?.repeatCount == 0) {
                backPressedTime = System.currentTimeMillis()
            }
            // Return true to "consume" the event so the system doesn't close the app yet
            return true 
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            val pressDuration = System.currentTimeMillis() - backPressedTime

            if (pressDuration >= LONG_PRESS_THRESHOLD) {
                // It was a long press! Show the Gemini UI
                showGeminiMic()
            } else {
                // It was a short press, do normal back behavior
                super.onBackPressed() 
            }
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    private fun showGeminiMic() {
        bottomSheetBehavior.state = BottomSheetBehavior.STATE_EXPANDED
    }
}