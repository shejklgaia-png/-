package dev.sera.loader;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.os.SystemClock;
import android.view.View;

/**
 * SERA Loader v0.6: transparent, particle-only loading artwork.
 *
 * The view draws NO background rectangle, gradient, or opaque field.
 * Stage 1: square blue pixels materialize bottom-up, with three bright
 *          irregular white/cyan stripes and tiny upward sparks at the edge.
 * Stage 2: a transparent pause with the completed blue pixel field.
 * Stage 3: the square training-grid lines materialize bottom-up.
 * Final:   the sparse blue pixel field and square grid are fully static.
 *
 * Fully empty pixels reveal the application underneath: this is an explicit
 * change from the previous opaque loader. Touch pass-through is unchanged.
 */
public final class PixelRiseView extends View {
    private static final long RISE_MS = 1900L;
    private static final long HOLD_MS = 300L;
    private static final long GRID_MS = 1550L;
    private static final long TOTAL_MS = RISE_MS + HOLD_MS + GRID_MS;
    private static final long FRAME_MS = 33L;
    private static final int SPARK_COUNT = 118;

    private static final int[] BLUE_PIXELS = {
        0xff165491, 0xff246cba, 0xff358ed0, 0xff459fe0,
        0xff2677c1, 0xff80c8ee
    };
    private static final int TIP_WHITE = 0xfff5fcff;
    private static final int TIP_PALE = 0xffc7f0ff;
    private static final int TIP_CYAN = 0xff67cefa;
    // The training room uses a dark square grid. Keep the same visual language.
    private static final int GRID_LINE = 0xff111821;

    private final float density;
    private final Paint pixelPaint = new Paint();
    private final Paint tipPaint = new Paint();
    private final Paint sparkPaint = new Paint();
    private final Paint gridPaint = new Paint();
    private final Path gridClip = new Path();

    private int cellSize;
    private int columns;
    private int rows;
    private float gridSpacing;
    private long animationStart = -1L;
    private boolean attached;

    public PixelRiseView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        pixelPaint.setAntiAlias(false);
        tipPaint.setAntiAlias(false);
        sparkPaint.setAntiAlias(false);
        gridPaint.setAntiAlias(false);
        gridPaint.setColor(GRID_LINE);
        gridPaint.setStrokeWidth(dp(1.45f));
        gridPaint.setAlpha(188);
        // No setBackground(), drawColor(), or background shader.
    }

    private float dp(float amount) { return amount * density; }
    private static float clamp(float x) {
        return x < 0f ? 0f : (x > 1f ? 1f : x);
    }
    private static float ease(float t) {
        t = clamp(t);
        return t * t * (3f - 2f * t);
    }
    private static float hash(int v) {
        int n = v * 0x45d9f3b;
        n = (n ^ (n >>> 16)) * 0x45d9f3b;
        n ^= n >>> 16;
        return (n & 0xffffff) / 16777216f;
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        attached = true;
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
        cellSize = Math.max(4, Math.round(dp(13f)));
        columns = (w + cellSize - 1) / cellSize;
        rows = (h + cellSize - 1) / cellSize;
        gridSpacing = dp(64f);
    }

    private float waveTop(int column, float t, int tick, int height) {
        float delay = hash(column * 457 + 23) * .13f;
        float local = clamp((t - delay) / (1f - delay));
        float noise = (hash(column * 113 + tick * 79 + 17) - .5f)
                * dp(19f) * (1f - local);
        return height - (height + dp(83f)) * ease(local) + noise;
    }

    private float gridTop(int column, float t, int tick, int height) {
        float delay = hash(column * 197 + 11) * .12f;
        float local = clamp((t - delay) / (1f - delay));
        float noise = (hash(column * 443 + tick * 37) - .5f)
                * dp(21f) * (1f - local);
        return Math.max(0f, Math.min(height,
                height - (height + dp(56f)) * ease(local) + noise));
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int w = getWidth(), h = getHeight();
        if (w <= 0 || h <= 0 || cellSize == 0) return;
        long elapsed = Math.max(0L,
                SystemClock.uptimeMillis() - animationStart);

        if (elapsed < RISE_MS) {
            drawBluePixels(canvas, w, h, elapsed, true);
            drawLeadingStrips(canvas, w, h, elapsed);
            drawSparks(canvas, w, h, elapsed, false);
        } else {
            // Once the first wave completes, only isolated blue pixels remain.
            // The area BETWEEN particles stays fully transparent.
            drawBluePixels(canvas, w, h, RISE_MS, false);
            long gridTime = elapsed - RISE_MS - HOLD_MS;
            if (gridTime >= 0L) {
                if (gridTime < GRID_MS) {
                    drawGridReveal(canvas, w, h, gridTime);
                    drawSparks(canvas, w, h, gridTime, true);
                } else {
                    drawTrainingGrid(canvas, w, h);
                }
            }
        }
        // Final artwork is static; no permanent animation loop.
        if (attached && elapsed < TOTAL_MS) postInvalidateDelayed(FRAME_MS);
    }

    private void drawBluePixels(Canvas canvas, int w, int h, long elapsed,
            boolean moving) {
        float t = elapsed / (float) RISE_MS;
        int tick = (int)(elapsed / 95L);

        // Non-contiguous rectangles only. No background is ever filled.
        for (int col = 0; col < columns; col++) {
            float head = moving ? waveTop(col, t, tick, h) : -dp(83f);
            float left = col * cellSize;
            for (int row = 0; row < rows; row++) {
                float top = row * cellSize;
                if (top + cellSize <= head) continue;
                int id = col * 977 + row * 313;
                float selection = hash(id + 17);
                if (selection < .40f) continue; // 40% of cells remain clear.

                float size = cellSize * (.28f + hash(id+63)*.63f);
                float x = left + hash(id+143)*(cellSize-size);
                float y = top + hash(id+221)*(cellSize-size);
                if (y + size < head) continue;

                int index = Math.min(BLUE_PIXELS.length-1,
                        (int)(hash(id+283)*BLUE_PIXELS.length));
                pixelPaint.setColor(BLUE_PIXELS[index]);
                int alpha = 65 + (int)(hash(id+91)*130f);
                // The newest pixels glow slightly more during construction.
                if(moving && y-head < dp(70f)) alpha =
                        Math.min(225, alpha+32);
                pixelPaint.setAlpha(alpha);
                canvas.drawRect(x,y,Math.min(w,x+size),
                        Math.min(h,y+size),pixelPaint);

                // A smaller blue subpixel makes the cloud more intricate.
                if (hash(id+503) > .78f) {
                    float dot = dp(1.6f + hash(id+641)*2.2f);
                    float dx = Math.min(w - dot,
                            left + cellSize*.60f);
                    float dy = Math.min(h - dot, top + cellSize*.16f);
                    pixelPaint.setColor(TIP_CYAN);
                    pixelPaint.setAlpha(55+(int)(hash(id+817)*110f));
                    canvas.drawRect(dx,dy,dx+dot,dy+dot,pixelPaint);
                }
            }
        }
    }

    private void drawLeadingStrips(Canvas canvas, int w, int h, long elapsed) {
        int tick = (int)(elapsed/95L);
        float progress = elapsed/(float)RISE_MS;
        float stripHeight=dp(11f);
        for (int col=0; col<columns; col++) {
            float head=waveTop(col,progress,tick,h);
            if(head>=h || head < -dp(45f)) continue;
            float x=col*cellSize;
            float right=Math.min(w,x+cellSize);
            for(int layer=0;layer<3;layer++) {
                float noise=hash(col*829+tick*41+layer*353);
                if(noise < (layer==0?.13f:.22f))continue;
                float top=Math.max(0f,head+layer*stripHeight
                        +(noise-.5f)*dp(5f));
                float bottom=Math.min(h,head+(layer+1)*stripHeight
                        +(noise-.5f)*dp(5f));
                if(bottom<=top)continue;
                tipPaint.setColor(layer==0 ? TIP_WHITE :
                        (layer==1 ? TIP_PALE : TIP_CYAN));
                tipPaint.setAlpha(Math.min(255,(layer==0 ? 175 :
                        layer==1 ? 120 : 70)+(int)(noise*70)));
                canvas.drawRect(x,top,right,bottom,tipPaint);
            }
        }
    }

    private void drawGridReveal(Canvas canvas,int w,int h,long elapsed) {
        float t=elapsed/(float)GRID_MS;
        int tick=(int)(elapsed/105L);
        float span=Math.max(dp(10f),cellSize);
        int count=(int)Math.ceil(w/span);
        gridClip.reset();
        gridClip.moveTo(0,h);
        for(int col=0; col<count;col++) {
            float x=col*span, right=Math.min(w,x+span);
            float front=gridTop(col,t,tick,h);
            gridClip.lineTo(x,front);
            gridClip.lineTo(right,front);
        }
        gridClip.lineTo(w,h);
        gridClip.close();
        canvas.save();
        canvas.clipPath(gridClip);
        drawTrainingGrid(canvas,w,h);
        canvas.restore();
    }

    private void drawTrainingGrid(Canvas canvas,int w,int h) {
        // Lines only: no filled grid cells or opaque floor layer.
        float x0=(w*.5f)%gridSpacing;
        float y0=(h*.5f)%gridSpacing;
        for(float x=x0;x<=w;x+=gridSpacing)
            canvas.drawLine(x,0,x,h,gridPaint);
        for(float y=y0;y<=h;y+=gridSpacing)
            canvas.drawLine(0,y,w,y,gridPaint);
    }

    private void drawSparks(Canvas canvas,int w,int h,long elapsed,
            boolean grid) {
        float t=elapsed/(float)(grid?GRID_MS:RISE_MS);
        int tick=(int)(elapsed/(grid?105L:95L));
        float seconds=elapsed*.001f;
        float span=Math.max(dp(10f),cellSize);
        for(int i=0;i<SPARK_COUNT;i++) {
            float x=hash(i*947+31)*w;
            int col=(int)(x/(grid?span:cellSize));
            float front=grid?gridTop(col,t,tick,h):
                    waveTop(col,t,tick,h);
            if(front < -dp(44f)||front>h+dp(30f))continue;
            float life=(seconds*(1.05f+hash(i*211+5)*1.85f)
                    +hash(i*331+9)*4.5f)%1f;
            float y=front+dp(38f)-life*dp(125f);
            if(y<0f||y>h)continue;
            float size=dp(1.6f+hash(i*727+13)*4.4f);
            float x2=x+(hash(i*149+tick*17)-.5f)*dp(13f);
            sparkPaint.setColor(i%7==0?TIP_WHITE:
                    i%3==0?TIP_PALE:TIP_CYAN);
            sparkPaint.setAlpha((int)((60f+165f*hash(i*337+23))*(1f-life)));
            canvas.drawRect(x2,y,x2+size,y+size,sparkPaint);
        }
    }
}
