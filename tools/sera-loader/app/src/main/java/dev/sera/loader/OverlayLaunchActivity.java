package dev.sera.loader;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;

/** Only launched by Automate: start the overlay, then remove our activity immediately. */
public final class OverlayLaunchActivity extends Activity {
    @Override public void onCreate(Bundle b){
        super.onCreate(b);
        if(!Settings.canDrawOverlays(this)){
            startActivity(new Intent(this,MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } else {
            startForegroundService(new Intent(this,OverlayService.class).setAction(OverlayService.ACTION_SHOW));
        }
        finish();
    }
}
