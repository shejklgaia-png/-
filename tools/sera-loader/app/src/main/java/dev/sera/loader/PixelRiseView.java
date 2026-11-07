package dev.sera.loader;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;
import android.os.SystemClock;
import android.view.View;

/**
 * SERA Loader v0.8.
 *
 * Initial surface: transparent.
 * Phase 1: ADJACENT OPAQUE blue columns rise from the bottom and cover all
 *          pixels below a ragged white/cyan triple-layer front. White
 *          sparks are only temporary accents around the climbing edge.
 * Phase 2: all screen pixels are blue (fully opaque), with a subtle blue
 *          vertical gradient; no white bands or lingering particle holes.
 * Phase 3: the training-room's dark square grid materializes from the bottom.
 * Final:   fully opaque blue background + square grid, drifting continuously
 *          diagonally toward the upper-right. The tile pattern wraps without
 *          a visible seam; only the grid moves, not the blue background.
 *
 * This view is behind the original centered SERA helmet and UI.
 * The accessibility overlay remains touch-through.
 */
public final class PixelRiseView extends View {
    private static final long RISE_MS = 1900L;
    private static final long HOLD_MS = 300L;
    private static final long GRID_MS = 1550L;
    private static final long TOTAL_MS = RISE_MS + HOLD_MS + GRID_MS;
    private static final long FRAME_MS = 33L;
    private static final int SPARK_COUNT = 100;
    // Slow, continual diagonal scroll of the training-room grid only.
    // One cell is 64dp; modulo wrap makes movement seamless.
    private static final float GRID_RIGHT_DP_PER_SEC = 18f;
    private static final float GRID_UP_DP_PER_SEC = 18f;

    private static final int[] FULL_BLUE = {
        0xff237abb, 0xff1e6baa, 0xff12518d
    };
    private static final int WHITE = 0xfff6fcff;
    private static final int ICE = 0xffc8f1ff;
    private static final int CYAN = 0xff6bd1fc;
    private static final int GRID = 0xff111821;

    private final Paint bluePaint = new Paint();
    private final Paint tipPaint = new Paint();
    private final Paint sparklePaint = new Paint();
    private final Paint gridPaint = new Paint();
    private final Paint rimPaint = new Paint();
    private final Path gridClip = new Path();

    private final float density;
    private int bandWidth;
    private int columns;
    private float gridSpacing;
    private long start = -1L;
    private boolean attached;

    public PixelRiseView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        tipPaint.setAntiAlias(false);
        sparklePaint.setAntiAlias(false);
        rimPaint.setAntiAlias(false);
        gridPaint.setAntiAlias(false);
        gridPaint.setStrokeWidth(dp(1.6f));
        gridPaint.setColor(GRID);
        // The view deliberately has no background; before a column passes,
        // the screen underneath is visible.
    }

    private float dp(float v) { return v*density; }
    private static float limit(float v) {
        return Math.max(0f,Math.min(1f,v));
    }
    private static float smooth(float t) {
        t=limit(t);
        return t*t*(3f-2f*t);
    }
    private static float noise(int seed) {
        int n=seed*0x45d9f3b;
        n=(n^(n>>>16))*0x45d9f3b;
        n=n^(n>>>16);
        return (n&0x00ffffff)/16777216f;
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        attached = true;
        start = SystemClock.uptimeMillis();
        postInvalidateOnAnimation();
    }

    @Override protected void onDetachedFromWindow() {
        attached = false;
        super.onDetachedFromWindow();
    }

    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH) {
        super.onSizeChanged(w,h,oldW,oldH);
        if(w<=0||h<=0)return;
        bandWidth=Math.max(3,Math.round(dp(12f)));
        columns=(w+bandWidth-1)/bandWidth;
        gridSpacing=dp(64f);
        // Paint colors interpolate only within opaque blue. Alpha is 255.
        bluePaint.setShader(new LinearGradient(0f,0f,0f,h,
                FULL_BLUE,new float[]{0f,.55f,1f},Shader.TileMode.CLAMP));
        bluePaint.setAlpha(255);
    }

    private float columnHead(int c,float phase,int tick,int h){
        float delay=noise(c*457+23)*.12f;
        float local=limit((phase-delay)/(1f-delay));
        float jitter=(noise(c*113+tick*79+17)-.5f)
                *dp(18f)*(1f-local);
        return h-(h+dp(76f))*smooth(local)+jitter;
    }

    private float gridHead(int c,float phase,int tick,int h) {
        float delay=noise(c*197+11)*.12f;
        float local=limit((phase-delay)/(1f-delay));
        float jitter=(noise(c*443+tick*37)-.5f)
                *dp(20f)*(1f-local);
        return Math.max(0f,Math.min(h,
                h-(h+dp(50f))*smooth(local)+jitter));
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int w=getWidth(),h=getHeight();
        if(w<=0||h<=0||bandWidth<=0)return;
        long ms=Math.max(0L,SystemClock.uptimeMillis()-start);

        if(ms<RISE_MS) {
            // NO full-screen fill in stage 1. Only blue columns are opaque;
            // their continuous rectangles cover all pixels below the tips.
            drawRisingBlue(canvas,w,h,ms);
            drawMicroSparks(canvas,w,h,ms,false);
        } else {
            // After ALL rising columns reach the top, this single opaque
            // gradient matches their blue paint. There are no pixel holes.
            canvas.drawRect(0f,0f,w,h,bluePaint);
            long gridMs=ms-RISE_MS-HOLD_MS;
            if(gridMs>=0L) {
                if(gridMs<GRID_MS) {
                    drawRisingGrid(canvas,w,h,gridMs);
                    drawMicroSparks(canvas,w,h,gridMs,true);
                } else {
                    drawTrainingGrid(canvas,w,h,gridMs);
                }
            }
        }
        // Keep the grid moving while the overlay is visible. The accessibility
        // service removes this view on GodotGame detection or its 120s timeout.
        if(attached)postInvalidateDelayed(FRAME_MS);
    }

    private void drawRisingBlue(Canvas canvas,int w,int h,long ms) {
        float phase=ms/(float)RISE_MS;
        int tick=(int)(ms/92L);
        float layerHeight=dp(12f);

        for(int c=0;c<columns;c++) {
            float x=c*bandWidth;
            float right=Math.min(w,x+bandWidth);
            float head=columnHead(c,phase,tick,h);
            if(head>=h)continue;

            // Adjacent columns share edges, so the lower blue field contains
            // no transparent gaps, regardless of the white tips' randomness.
            canvas.drawRect(x,Math.max(0f,head),right,h,bluePaint);
            if(head < -dp(44f))continue;
            for(int layer=0;layer<3;layer++) {
                float n=noise(c*829+tick*41+layer*353);
                if(n<(layer==0?.10f:.20f))continue;
                float a=Math.max(0f,
                        head+layer*layerHeight+(n-.5f)*dp(5f));
                float b=Math.min(h,
                        head+(layer+1)*layerHeight+(n-.5f)*dp(5f));
                if(b<=a)continue;
                tipPaint.setColor(layer==0?WHITE:(layer==1?ICE:CYAN));
                tipPaint.setAlpha(Math.min(255,
                        (layer==0?185:(layer==1?140:75))+(int)(n*65)));
                canvas.drawRect(x,a,right,b,tipPaint);
            }
            float rim=noise(c*239+tick*19);
            if(head>0f&&rim>.84f){
                rimPaint.setColor(ICE);
                rimPaint.setAlpha(60+(int)(rim*100f));
                canvas.drawRect(x,Math.max(0f,head-dp(2f)),right,
                        Math.min(h,head+dp(2f)),rimPaint);
            }
        }
    }

    private void drawRisingGrid(Canvas canvas,int w,int h,long ms) {
        float phase=ms/(float)GRID_MS;
        int tick=(int)(ms/100L);
        float span=Math.max(dp(10f),bandWidth);
        int count=(int)Math.ceil(w/span);

        gridClip.reset();
        gridClip.moveTo(0,h);
        for(int c=0;c<count;c++){
            float x=c*span;
            float right=Math.min(w,x+span);
            float head=gridHead(c,phase,tick,h);
            gridClip.lineTo(x,head);
            gridClip.lineTo(right,head);
        }
        gridClip.lineTo(w,h);
        gridClip.close();
        canvas.save();
        canvas.clipPath(gridClip);
        drawTrainingGrid(canvas,w,h,ms);
        canvas.restore();

        for(int c=0;c<count;c++) {
            float n=noise(c*613+tick*61);
            if(n<.53f)continue;
            float head=gridHead(c,phase,tick,h);
            if(head<=0f||head>=h)continue;
            float x=c*span;
            rimPaint.setColor(n>.83f?WHITE:CYAN);
            rimPaint.setAlpha(45+(int)(n*110f));
            canvas.drawRect(x,Math.max(0f,head-dp(1f)),
                    Math.min(w,x+span),Math.min(h,head+dp(3f)),rimPaint);
        }
    }

    private static float wrap(float pos,float cell) {
        float result=pos%cell;
        return result<0f ? result+cell : result;
    }

    private void drawTrainingGrid(Canvas canvas,int w,int h,long gridMs) {
        // 64dp square cells, dark lines matched to SERA's training floor.
        // X moves right and Y moves up continuously, including AFTER the
        // irregular bottom-up reveal is finished. Only screen-space offsets
        // change, never the absolute grid spacing or its square proportions.
        float seconds=gridMs*.001f;
        float ox=wrap((w*.5f)%gridSpacing
                +dp(GRID_RIGHT_DP_PER_SEC)*seconds,gridSpacing);
        float oy=wrap((h*.5f)%gridSpacing
                -dp(GRID_UP_DP_PER_SEC)*seconds,gridSpacing);

        // Extra line off each edge prevents holes during modulo wrapping.
        for(float x=ox-gridSpacing;x<=w+gridSpacing;x+=gridSpacing)
            canvas.drawLine(x,0f,x,h,gridPaint);
        for(float y=oy-gridSpacing;y<=h+gridSpacing;y+=gridSpacing)
            canvas.drawLine(0f,y,w,y,gridPaint);
    }

    private void drawMicroSparks(Canvas canvas,int w,int h,long ms,
            boolean grid) {
        float phase=ms/(float)(grid?GRID_MS:RISE_MS);
        float secs=ms*.001f;
        int tick=(int)(ms/(grid?100L:92L));
        float span=Math.max(dp(10f),bandWidth);
        for(int i=0;i<SPARK_COUNT;i++) {
            float x=noise(i*947+31)*w;
            int col=(int)(x/(grid?span:bandWidth));
            float front=grid?gridHead(col,phase,tick,h):
                    columnHead(col,phase,tick,h);
            if(front < -dp(45f)||front>h+dp(30f))continue;
            float life=(secs*(1.07f+noise(i*211+5)*1.7f)
                    +noise(i*331+9)*4.5f)%1f;
            float y=front+dp(44f)-life*dp(130f);
            if(y<0f||y>h)continue;
            float size=dp(1.5f+noise(i*727+13)*4.5f);
            float xx=x+(noise(i*149+tick*17)-.5f)*dp(12f);
            sparklePaint.setColor(i%7==0?WHITE:(i%3==0?ICE:CYAN));
            sparklePaint.setAlpha((int)(
                    (60f+175f*noise(i*337+23))*(1f-life)));
            canvas.drawRect(xx,y,xx+size,y+size,sparklePaint);
        }
    }
}
