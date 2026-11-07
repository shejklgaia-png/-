package dev.sera.loader;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.graphics.Color;
import android.graphics.Typeface;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class MainActivity extends Activity {
    private TextView state;
    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout root=new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(dp(30),dp(25),dp(30),dp(25));
        root.setBackgroundColor(Color.rgb(17,23,32));
        TextView title=new TextView(this);
        title.setText("SERA LOADER"); title.setTextSize(26); title.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        title.setTextColor(Color.WHITE); title.setGravity(Gravity.CENTER);
        root.addView(title,new LinearLayout.LayoutParams(-1,dp(60)));
        state=new TextView(this);state.setTextColor(Color.LTGRAY);state.setTextSize(14);state.setGravity(Gravity.CENTER);
        root.addView(state,new LinearLayout.LayoutParams(-1,dp(80)));
        Button permission=new Button(this); permission.setText("1  重ねて表示を許可");
        permission.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:"+getPackageName()))));
        root.addView(permission,new LinearLayout.LayoutParams(-1,dp(60)));
        Button start=new Button(this);start.setText("2  ロード画面をテスト表示");
        start.setOnClickListener(v -> {
            if(!Settings.canDrawOverlays(this)){refresh();return;}
            if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=getPackageManager().PERMISSION_GRANTED)
               requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},2);
            Intent i=new Intent(this,OverlayService.class).setAction(OverlayService.ACTION_SHOW);
            startForegroundService(i);
            moveTaskToBack(true);
        });
        root.addView(start,new LinearLayout.LayoutParams(-1,dp(60)));
        Button accessibilitySettings=new Button(this);
        accessibilitySettings.setText("3  ユーザー補助サービスを設定");
        accessibilitySettings.setOnClickListener(v ->
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        root.addView(accessibilitySettings,new LinearLayout.LayoutParams(-1,dp(60)));
        Button opaqueTest=new Button(this);
        opaqueTest.setText("4  完全不透明ロード画面をテスト");
        opaqueTest.setOnClickListener(v -> {
            if(SeraAccessibilityOverlayService.requestShow()) {
                stopService(new Intent(this,OverlayService.class));
                moveTaskToBack(true);
            } else {
                state.setText("ユーザー補助サービスが未接続です。設定で有効にしてください。");
            }
        });
        root.addView(opaqueTest,new LinearLayout.LayoutParams(-1,dp(60)));

        Button stop=new Button(this);stop.setText("ロード画面を終了");
        stop.setOnClickListener(v -> { stopService(new Intent(this,OverlayService.class)); SeraAccessibilityOverlayService.requestHide(); });
        root.addView(stop,new LinearLayout.LayoutParams(-1,dp(60)));
        TextView note=new TextView(this);
        note.setText("2：従来の78％表示。4：ユーザー補助による完全不透明表示。\n画面の内容は取得せず、120秒で自動解除します。");
        note.setTextColor(Color.LTGRAY); note.setTextSize(12); note.setPadding(0,dp(25),0,0);
        root.addView(note);
        setContentView(root);
    }
    @Override public void onResume(){super.onResume(); refresh();}
    private void refresh(){if(state!=null) state.setText("通常オーバーレイ：" + (Settings.canDrawOverlays(this)?"許可済み":"未許可") + "\nユーザー補助：" + (SeraAccessibilityOverlayService.isReady()?"接続済み":"未接続"));}
    private int dp(float d){return (int)(d*getResources().getDisplayMetrics().density+0.5f);}
}
