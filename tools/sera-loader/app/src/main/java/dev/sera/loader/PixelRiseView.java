package dev.sera.loader;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.LinearGradient;
import android.graphics.Shader;
import android.os.SystemClock;
import android.view.View;

/**
 * SERA Loader: two-stage electronic background materialization.
 *
 * Stage 1: bottom-up blue strips with three ragged white/cyan leading bands.
 * Pause:   a completely uniform blue field.
 * Stage 2: the training-floor square grid grows bottom-up with a rough edge.
 * Final:   an absolutely static solid-blue background with dark square grid.
 *
 * Never reads touches, UI contents or accessibility data.
 * The separate SERA helmet, headings and progress bar sit above this view.
 */
public final class PixelRiseView extends View {
    // Tunable animation timings. Do not change Automate's Godot detection.
    private static final long BLUE_FILL_MS = 1900L;
    private static final long BLUE_HOLD_MS = 300L;
    private static final long GRID_FILL_MS = 1550L;
    private static final long TOTAL_MS =
            BLUE_FILL_MS + BLUE_HOLD_MS + GRID_FILL_MS;
    private static final long FRAME_MS = 33L;

    // Match the existing training room's grid line color (#111821).
    // The background itself is intentionally ONE uniform electronic blue.
    private static final int[] BASE_BLUE = {0xff103b74,0xff12549a,0xff0b427f};
    private static final int[] FINISHED_BLUE = {0xff3286c8,0xff216db4,0xff14529b};
    private static final int SPARK_COUNT = 96;
    private static final int GRID_LINE = 0xff111821;

    private static final int TIP_WHITE = 0xfff6fcff;
    private static final int TIP_ICE = 0xffbdeaff;
    private static final int TIP_CYAN = 0xff63c4f4;

    private final Paint solidPaint = new Paint();
    private final Paint basePaint = new Paint();
    private final Paint finalPaint = new Paint();
    private final Paint sparkle = new Paint();
    private final Paint shine = new Paint();
    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint tipPaint = new Paint();
    private final Path gridRevealPath = new Path();

    private final float density;
    private long animationStart = -1L;
    private int columnWidth;
    private int revealColumns;
    private float gridSpacing;
    private boolean attached;

    public PixelRiseView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        solidPaint.setStyle(Paint.Style.FILL);
        tipPaint.setStyle(Paint.Style.FILL);
        tipPaint.setAntiAlias(false); // Square, sharply defined electronic tips.
        linePaint.setColor(GRID_LINE);
        linePaint.setStyle(Paint.Style.STROKE);
        linePaint.setStrokeWidth(dp(1.6f));
        linePaint.setAntiAlias(false);
    }

    private float dp(float value) {
        return value * density;
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        attached = true;
        // A fresh loading-screen instance always begins at the first wave.
        animationStart = SystemClock.uptimeMillis();
        postInvalidateOnAnimation();
    }

    @Override protected void onDetachedFromWindow() {
        attached = false;
        super.onDetachedFromWindow();
    }

    @Override protected void onSizeChanged(int w, int h, int oldW, int oldH) {
        super.onSizeChanged(w, h, oldW, oldH);
        if (w <= 0 || h <= 0) return;
        // Close-set vertical digital bars instead of randomly colored blocks.
        columnWidth = Math.max(3, Math.round(dp(12f)));
        revealColumns = (w + columnWidth - 1) / columnWidth;

        // The SERA training floor uses square cells (4m per cell in-world)
        // and narrow, very dark lines. 2D equivalent keeps square proportions.
        gridSpacing = dp(64f);
        // Fully blue gradients cover the screen from the first frame.
        basePaint.setShader(new LinearGradient(0f,0f,0f,h,BASE_BLUE,
                new float[]{0f,.55f,1f},Shader.TileMode.CLAMP));
        finalPaint.setShader(new LinearGradient(0f,0f,0f,h,FINISHED_BLUE,
                new float[]{0f,.52f,1f},Shader.TileMode.CLAMP));
        solidPaint.setShader(finalPaint.getShader());
    }

    private static float clamp01(float x) {
        return x < 0f ? 0f : (x > 1f ? 1f : x);
    }

    private static float smooth(float progress) {
        float t = clamp01(progress);
        return t * t * (3f - 2f * t);
    }

    /** Deterministic, fast, allocation-free noise with output in [0,1). */
    private static float hash(int value) {
        int n = value * 0x45d9f3b;
        n = (n ^ (n >>> 16)) * 0x45d9f3b;
        n = n ^ (n >>> 16);
        return (n & 0x00ffffff) / 16777216f;
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        final int w = getWidth();
        final int h = getHeight();
        if (w <= 0 || h <= 0 || columnWidth <= 0) return;

        final long elapsed = Math.max(0L,
                SystemClock.uptimeMillis() - animationStart);

        if (elapsed < BLUE_FILL_MS) {
            drawBlueFormation(canvas, w, h, elapsed);
        } else {
            // Deliberately opaque flat color. No residual tips or gradients.
            canvas.drawRect(0,0,w,h,finalPaint);
            if (elapsed >= BLUE_FILL_MS + BLUE_HOLD_MS) {
                final long gridElapsed =
                    elapsed - BLUE_FILL_MS - BLUE_HOLD_MS;
                if (gridElapsed >= GRID_FILL_MS) {
                    drawTrainingGrid(canvas, w, h);
                } else {
                    drawGridFormation(canvas, w, h, gridElapsed);
                }
            }
        }

        // Stop all drawing after the second wave: the last image is static.
        if (attached && elapsed < TOTAL_MS) {
            postInvalidateDelayed(FRAME_MS);
        }
    }

    private void drawBlueFormation(Canvas canvas, int w, int h, long elapsed) {
        canvas.drawRect(0,0,w,h,basePaint);
        final float t = elapsed / (float) BLUE_FILL_MS;
        final int tick = (int) (elapsed / 95L);
        final float leadHeight = dp(12f);

        // Blue strips are painted with the finished blue gradient.
        for (int c = 0; c < revealColumns; c++) {
            final float x = c * columnWidth;
            final float right = Math.min(w, x + columnWidth);
            // Stagger individual vertical strips and keep their leading edge
            // organically uneven. All strips nevertheless finish by 1.9s.
            final float startDelay = hash(c * 457 + 23) * 0.12f;
            final float local = clamp01((t - startDelay) / (1f - startDelay));
            if (local <= 0f) continue;

            final float edgeNoise =
                    (hash(c * 113 + tick * 79 + 17) - .5f) * dp(16f);
            final float columnHeight = (h + dp(65f)) * smooth(local);
            final float head = h - columnHeight
                    + (1f - local) * edgeNoise;
            final float blueTop = Math.max(0f, head);

            canvas.drawRect(x, blueTop, right, h, solidPaint);

            // Three bright layers at the FRONT only. The already-generated
            // lower portion remains exactly the same uniform SOLID_BLUE.
            // Flicker/uneven whites affect only these three short segments.
            if (head >= h || head < -dp(52f)) continue;
            for (int band = 0; band < 3; band++) {
                final float n = hash(c * 829 + tick * 41 + band * 353);
                if (n < (band == 0 ? .12f : .23f)) continue;
                final float top = Math.max(0f,
                        head + band * leadHeight + (n - .5f) * dp(5f));
                final float bottom = Math.min(h,
                        head + (band + 1) * leadHeight + (n - .5f) * dp(5f));
                if (bottom <= top) continue;
                tipPaint.setColor(band == 0 ? TIP_WHITE
                        : (band == 1 ? TIP_ICE : TIP_CYAN));
                final int alphaBase = band == 0 ? 185 :
                        (band == 1 ? 126 : 70);
                tipPaint.setAlpha(Math.min(255,
                        alphaBase + (int)(n * (band == 0 ? 70 : 55))));
                canvas.drawRect(x, top, right, bottom, tipPaint);
            }
            // Sparse fine edge gleams, invisible in the completed background.
            float blink = hash(c * 239 + tick * 19);
            if (head > 0f && blink > .80f) {
                shine.setColor(TIP_ICE);
                shine.setAlpha(55 + (int)(blink * 100f));
                canvas.drawRect(x,Math.max(0f,head-dp(2f)),right,
                    Math.min(h,head+dp(1.6f)),shine);
            }
        }
        drawFineSparks(canvas,w,h,elapsed,false);
    }

    private void drawGridFormation(Canvas canvas, int w, int h,
            long gridElapsed) {
        final float t = gridElapsed / (float) GRID_FILL_MS;
        final int tick = (int) (gridElapsed / 105L);
        final float span = Math.max(dp(10f), columnWidth);
        final int cols = (int)Math.ceil(w / span);

        // The front is a slightly ragged, pixel-stepped contour.
        // The grid behind it is always regular and perfectly square.
        gridRevealPath.reset();
        gridRevealPath.moveTo(0f, h);
        for (int i = 0; i < cols; i++) {
            float x = i * span;
            float right = Math.min(w, x + span);
            float delay = hash(i * 197 + 11) * .12f;
            float local = clamp01((t - delay) / (1f - delay));
            float jitter = (hash(i * 443 + tick * 37) - .5f)
                    * dp(20f) * (1f - local);
            float tip = h - (h + dp(42f)) * smooth(local) + jitter;
            tip = Math.max(0f, Math.min(h, tip));
            gridRevealPath.lineTo(x, tip);
            gridRevealPath.lineTo(right, tip);
        }
        gridRevealPath.lineTo(w, h);
        gridRevealPath.close();

        canvas.save();
        canvas.clipPath(gridRevealPath);
        drawTrainingGrid(canvas, w, h);
        canvas.restore();

        // Randomized cyan/white glints at the moving grid construction edge.
        for(int i=0;i<cols;i++) {
            float glint=hash(i*613+tick*61);
            if(glint<.45f)continue;
            float delay=hash(i*197+11)*.12f;
            float local=clamp01((t-delay)/(1f-delay));
            float jitter=(hash(i*443+tick*37)-.5f)*dp(20f)*(1f-local);
            float y=Math.max(0f,Math.min(h,
                h-(h+dp(42f))*smooth(local)+jitter));
            if(y<=0f||y>=h)continue;
            shine.setColor(glint>.83f?TIP_WHITE:TIP_CYAN);
            shine.setAlpha(50+(int)(glint*106f));
            float x=i*span;
            canvas.drawRect(x,Math.max(0f,y-dp(1f)),
                Math.min(w,x+span),Math.min(h,y+dp(2.7f)),shine);
        }
        drawFineSparks(canvas,w,h,gridElapsed,true);
    }

    // 2–7dp square particles rise only at each active leading edge.
    private void drawFineSparks(Canvas canvas,int w,int h,long ms,boolean grid){
        float t=ms/(float)(grid?GRID_FILL_MS:BLUE_FILL_MS);
        float seconds=ms*.001f;
        int tick=(int)(ms/(grid?105L:95L));
        float span=Math.max(dp(10f),columnWidth);
        for(int i=0;i<SPARK_COUNT;i++){
            float x=hash(i*947+31)*w;
            int col=(int)(x/(grid?span:columnWidth));
            float delay=grid?hash(col*197+11)*.12f:hash(col*457+23)*.12f;
            float local=clamp01((t-delay)/(1f-delay));
            float head;
            if(grid){
                float jitter=(hash(col*443+tick*37)-.5f)*dp(20f)*(1f-local);
                head=h-(h+dp(42f))*smooth(local)+jitter;
            } else {
                float jitter=(hash(col*113+tick*79+17)-.5f)*dp(16f);
                head=h-(h+dp(65f))*smooth(local)+(1f-local)*jitter;
            }
            if(head < -dp(40f)||head>h+dp(30f))continue;
            float life=(seconds*(1.1f+hash(i*211+5)*1.7f)
                +hash(i*331+9)*4.5f)%1f;
            float y=head+dp(41f)-life*dp(126f);
            if(y<0f||y>h)continue;
            float size=dp(2f+hash(i*727+13)*4.6f);
            float x2=x+(hash(i*149+tick*17)-.5f)*dp(12f);
            sparkle.setColor(i%6==0?TIP_WHITE:(i%3==0?TIP_ICE:TIP_CYAN));
            sparkle.setAlpha((int)((60f+155f*hash(i*337+23))*(1f-life)));
            canvas.drawRect(x2,y,x2+size,y+size,sparkle);
        }
    }

    private void drawTrainingGrid(Canvas canvas, int w, int h) {
        linePaint.setColor(GRID_LINE);
        // Matching a 4m-by-4m square floor cell: both axes use the exact
        // same spacing and the scene's original dark line color (#111821).
        final float originX = (w * .5f) % gridSpacing;
        final float originY = (h * .5f) % gridSpacing;
        for (float x = originX; x <= w; x += gridSpacing) {
            canvas.drawLine(x, 0, x, h, linePaint);
        }
        for (float y = originY; y <= h; y += gridSpacing) {
            canvas.drawLine(0, y, w, y, linePaint);
        }
    }
}
