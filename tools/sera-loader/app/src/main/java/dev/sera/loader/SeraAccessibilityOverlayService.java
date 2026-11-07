package dev.sera.loader;

import android.Manifest;
import android.accessibilityservice.AccessibilityService;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import java.lang.ref.WeakReference;

/** Opaque trusted overlay; no accessibility event reads or action injection. */
public final class SeraAccessibilityOverlayService extends AccessibilityService {
    private static final String TAG="SeraLoaderA11y";
    private static final String CHANNEL="sera_accessibility_loader";
    private static final int NOTIFICATION_ID=87;
    private static WeakReference<SeraAccessibilityOverlayService> active=new WeakReference<>(null);

    private final Handler handler=new Handler(Looper.getMainLooper());
    private final Runnable timeout=this::hideOverlay;
    private WindowManager wm;
    private View overlay;

    public static boolean isReady(){ return active.get()!=null; }
    public static boolean requestShow(){
        SeraAccessibilityOverlayService service=active.get();
        if(service==null) return false;
        service.handler.post(service::showOverlay);
        return true;
    }
    public static void requestHide(){
        SeraAccessibilityOverlayService service=active.get();
        if(service!=null) service.handler.post(service::hideOverlay);
    }
    @Override protected void onServiceConnected(){
        super.onServiceConnected();
        active=new WeakReference<>(this);
    }
    @Override public void onAccessibilityEvent(AccessibilityEvent event){
        // Intentionally ignore events; never inspect UI data.
    }
    @Override public void onInterrupt(){ hideOverlay(); }
    @Override public boolean onUnbind(Intent intent){
        hideOverlay(); active.clear();
        return super.onUnbind(intent);
    }
    @Override public void onDestroy(){
        hideOverlay(); active.clear(); super.onDestroy();
    }
    private int dp(float v){return (int)(v*getResources().getDisplayMetrics().density+.5f);}
    private TextView label(String t,int size,int color,boolean bold){
        TextView v=new TextView(this);
        v.setText(t); v.setTextSize(size); v.setTextColor(color); v.setGravity(Gravity.CENTER);
        if(bold)v.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        return v;
    }
    private LinearLayout.LayoutParams margin(int w,int h,int top){
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(w,h);
        p.topMargin=dp(top); return p;
    }
    private void showOverlay(){
        handler.removeCallbacks(timeout);
        if(overlay!=null){handler.postDelayed(timeout,120000L);return;}
        wm=(WindowManager)getSystemService(WINDOW_SERVICE);
        FrameLayout root=new FrameLayout(this);
        // Blue-only gradient underlay prevents any charcoal flash at startup.
        android.graphics.drawable.GradientDrawable blueBackdrop =
            new android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xff103b74,0xff12549a,0xff0b427f});
        root.setBackground(blueBackdrop);
        // Animated square-particle layer stays BEHIND the existing SERA helmet,
        // headings, and progress bar. It does not handle any touch events.
        root.addView(new PixelRiseView(this),
            new FrameLayout.LayoutParams(-1,-1));
        LinearLayout column=new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER);
        column.setPadding(dp(24),0,dp(24),0);
        ImageView helmet=new ImageView(this);
        helmet.setImageResource(R.drawable.sera_helmet);
        helmet.setScaleType(ImageView.ScaleType.FIT_CENTER);
        column.addView(helmet,new LinearLayout.LayoutParams(dp(210),dp(210)));
        TextView name=label("SERA",34,Color.WHITE,true);
        name.setLetterSpacing(.2f);
        column.addView(name,margin(-1,dp(58),4));
        TextView status=label("PREPARING PROJECT",12,0xffaeb9c8,false);
        status.setLetterSpacing(.12f);
        column.addView(status,margin(-1,dp(44),0));
        ProgressBar bar=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);
        bar.setIndeterminate(true);
        bar.setIndeterminateTintList(android.content.res.ColorStateList.valueOf(0xffe5ebf4));
        column.addView(bar,margin(dp(230),dp(4),18));
        column.addView(label("DEVELOPMENT BUILD",10,0xff8492a5,false),
            margin(-1,dp(34),17));
        root.addView(column,new FrameLayout.LayoutParams(-1,-2,Gravity.CENTER));

        WindowManager.LayoutParams params=new WindowManager.LayoutParams(
            -1,-1,WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                |WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                |WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT);
        params.alpha=1.0f;
        params.gravity=Gravity.TOP|Gravity.START;
        try{
            wm.addView(root,params);
            overlay=root;
            handler.postDelayed(timeout,120000L);
            notifyClose();
        }catch(RuntimeException e){
            Log.e(TAG,"Unable to show overlay",e);
            hideOverlay();
        }
    }
    private void notifyClose(){
        NotificationManager nm=(NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL,"SERA Loader",
            NotificationManager.IMPORTANCE_LOW));
        if(Build.VERSION.SDK_INT>=33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
            return;
        PendingIntent dismiss=PendingIntent.getBroadcast(this,87,
            new Intent(this,HideReceiver.class).setAction("dev.sera.loader.HIDE"),
            PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Notification note=new Notification.Builder(this,CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("SERA — ロード画面表示中")
            .setContentText("最大120秒で自動解除")
            .setOngoing(true)
            .addAction(new Notification.Action.Builder(
                android.R.drawable.ic_menu_close_clear_cancel,"閉じる",dismiss).build())
            .build();
        try{nm.notify(NOTIFICATION_ID,note);}
        catch(SecurityException e){Log.w(TAG,"Notification blocked",e);}
    }
    private void hideOverlay(){
        handler.removeCallbacks(timeout);
        if(overlay!=null && wm!=null){
            try{wm.removeViewImmediate(overlay);}
            catch(RuntimeException e){Log.w(TAG,"Overlay already removed",e);}
        }
        overlay=null;
        ((NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE))
            .cancel(NOTIFICATION_ID);
    }
}
