package dev.sera.loader;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/** Automate launches this activity to request the trusted overlay. */
public final class OverlayLaunchActivity extends Activity {
    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        if (!SeraAccessibilityOverlayService.requestShow()) {
            startActivity(new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
        finish();
    }
}
