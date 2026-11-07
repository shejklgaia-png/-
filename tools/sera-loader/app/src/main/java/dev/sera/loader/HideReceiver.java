package dev.sera.loader;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Explicit ACTION_HIDE broadcast from Automate or the notification action. */
public final class HideReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if("dev.sera.loader.HIDE".equals(intent.getAction())) {
            context.stopService(new Intent(context,OverlayService.class));
        }
    }
}
