package dev.sera.loader;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class HideReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if ("dev.sera.loader.HIDE".equals(intent.getAction())) {
            SeraAccessibilityOverlayService.requestHide();
            context.stopService(new Intent(context, OverlayService.class));
        }
    }
}
