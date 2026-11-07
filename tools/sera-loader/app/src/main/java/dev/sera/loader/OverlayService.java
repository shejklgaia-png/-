package dev.sera.loader;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

public final class OverlayService extends Service {
    public static final String ACTION_SHOW="dev.sera.loader.SHOW";
    private static final String CHANNEL="sera_loader_status";
    private static final int NOTIFICATION_ID=32;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final Runnable timeout=this::stopSelf;
    private WindowManager windowManager;
    private View overlay;

    @Override public void onCreate() {
        super.onCreate();
        NotificationManager nm=(NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL,"SERA Loader",NotificationManager.IMPORTANCE_LOW));
        Intent hide=new Intent(this,HideReceiver.class).setAction("dev.sera.loader.HIDE");
        PendingIntent close=PendingIntent.getBroadcast(this,99,hide,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        Notification notification=new Notification.Builder(this,CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("SERA — 準備中")
            .setContentText("読み込み画面を表示しています")
            .setOngoing(true)
            .addAction(new Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel,"閉じる",close).build())
            .build();
        if(Build.VERSION.SDK_INT>=34) startForeground(NOTIFICATION_ID,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else startForeground(NOTIFICATION_ID,notification);
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId) {
        if (intent!=null && ACTION_SHOW.equals(intent.getAction())) {
            showOverlay();
            handler.removeCallbacks(timeout);
            handler.postDelayed(timeout,120000);
        }
        return START_NOT_STICKY;
    }

    private void showOverlay() {
        if(overlay!=null) return;
        if(!android.provider.Settings.canDrawOverlays(this)){stopSelf();return;}
        windowManager=(WindowManager)getSystemService(WINDOW_SERVICE);
        FrameLayout root=new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(13,19,28));
        LinearLayout content=new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setPadding(dp(28),0,dp(28),0);
        ImageView logo=new ImageView(this);
        logo.setImageResource(R.drawable.sera_helmet);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        content.addView(logo,new LinearLayout.LayoutParams(dp(216),dp(216)));
        TextView heading=text("SERA",34,Color.WHITE,true);
        heading.setLetterSpacing(.24f);
        content.addView(heading,margin(-1,dp(65),0,0));
        TextView title=text("PREPARING PROJECT",12,0xffbcc5d3,false);
        title.setLetterSpacing(.15f);
        content.addView(title,margin(-1,dp(42),0,0));
        ProgressBar progress=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);
        progress.setIndeterminate(true);
        if(Build.VERSION.SDK_INT>=21) progress.setIndeterminateTintList(android.content.res.ColorStateList.valueOf(0xffe5eaf4));
        content.addView(progress,margin(dp(230),dp(5),dp(22),0));
        TextView footer=text("DEVELOPMENT BUILD",10,0xff808e9f,false);
        footer.setLetterSpacing(.12f);
        content.addView(footer,margin(-1,dp(38),dp(18),0));
        FrameLayout.LayoutParams layout=new FrameLayout.LayoutParams(-1,-2,Gravity.CENTER);
        root.addView(content,layout);
        int flags=WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE|
                  WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE|
                  WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;
        WindowManager.LayoutParams params=new WindowManager.LayoutParams(-1,-1,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            flags,android.graphics.PixelFormat.TRANSLUCENT);
        // Android 12+ touch-through limit for untrusted overlays is <= 0.8 opacity.
        params.alpha=0.78f;
        params.gravity=Gravity.TOP|Gravity.START;
        try {
            windowManager.addView(root,params);
            overlay=root;
        }catch (RuntimeException e){ android.util.Log.e("SERALoader","Overlay denied",e);stopSelf(); }
    }
    private TextView text(String s,int size,int color,boolean bold){
        TextView view=new TextView(this);view.setText(s);view.setGravity(Gravity.CENTER);
        view.setTextColor(color);view.setTextSize(size);
        if(bold)view.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        return view;
    }
    private LinearLayout.LayoutParams margin(int w,int h,int top,int bottom){
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(w,h);
        p.topMargin=dp(top);p.bottomMargin=dp(bottom);return p;
    }
    private int dp(float value){return (int)(value*getResources().getDisplayMetrics().density+.5f);}
    @Override public void onDestroy(){
        handler.removeCallbacks(timeout);
        if(overlay!=null && windowManager!=null){try{windowManager.removeViewImmediate(overlay);}catch(Exception ignored){}}
        overlay=null;
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
}
