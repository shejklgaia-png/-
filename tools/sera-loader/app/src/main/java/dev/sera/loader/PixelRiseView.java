package dev.sera.loader;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.os.SystemClock;
import android.view.View;

/**
 * Lightweight electronic waterfall for the SERA loading overlay.
 *
 * The background grows upward as a coarse blue pixel field and bright square
 * fragments float upward at varied speeds. Drawn under the fixed helmet UI.
 * Only Canvas rectangles are used; no bitmap/video decoder or GPU particle
 * system is needed. Rendering stops automatically when detached.
 */
public final class PixelRiseView extends View {
    private static final long FILL_DURATION_MS = 3600L;
    private static final long FRAME_MS = 33L;
    private static final int FRAGMENT_COUNT = 88;
    private static final int BACKGROUND_COLOR = 0xff0c121a;

    private static final int[] TILES = {
        0xff10263b, 0xff16344c, 0xff1a4264,
        0xff20567c, 0xff2578ac, 0xff3898c6,
        0xff73bbdf, 0xffc4edff
    };
    private static final int[] FRAGMENTS = {
        0xff1681ba, 0xff35adf0, 0xff7edbff,
        0xffd4f2ff, 0xfff3fbff
    };

    private final Paint square = new Paint();
    private final Paint centerShade = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final float density;
    private final long startMs;
    private int pixelSize;
    private int columns;
    private int rows;
    private boolean running;

    public PixelRiseView(Context context) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        startMs = SystemClock.uptimeMillis();
        square.setAntiAlias(false); // Keep pixels deliberately sharp and square.
        setLayerType(View.LAYER_TYPE_HARDWARE, null);
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        running = true;
        postInvalidateOnAnimation();
    }

    @Override protected void onDetachedFromWindow() {
        running = false;
        super.onDetachedFromWindow();
    }

    private float dp(float value) {
        return value * density;
    }

    @Override protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        if (width <= 0 || height <= 0) return;

        // Chunky squares; the count adapts to portrait, landscape and density.
        pixelSize = Math.max(1, Math.round(dp(19f)));
        columns = (width + pixelSize - 1) / pixelSize;
        rows = (height + pixelSize - 1) / pixelSize;

        // A soft dark center keeps the original white face/text legible.
        float radius = Math.max(dp(170f), Math.min(width * 0.85f, height * 0.42f));
        centerShade.setShader(new RadialGradient(
                width * 0.5f, height * 0.5f, radius,
                new int[] {0xd909111c, 0x9c101c2b, 0x00101c2b},
                new float[] {0f, .43f, 1f}, Shader.TileMode.CLAMP));
    }

    /** Cheap deterministic hash; avoids allocation and random state in onDraw. */
    private static float noise(int input) {
        int n = input * 0x45d9f3b;
        n = (n ^ (n >>> 16)) * 0x45d9f3b;
        n = n ^ (n >>> 16);
        return (n & 0x00ffffff) * (1f / 16777216f);
    }

    @Override protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int width = getWidth();
        int height = getHeight();
        canvas.drawColor(BACKGROUND_COLOR);
        if (width == 0 || height == 0 || pixelSize == 0) return;

        long elapsed = Math.max(0L, SystemClock.uptimeMillis() - startMs);
        float seconds = elapsed * .001f;
        float progress = Math.min(1f, elapsed / (float) FILL_DURATION_MS);
        // A tiny ease-in makes the wave emerge organically rather than in one band.
        float front = height * (1f - progress * progress * (3f - 2f * progress));
        int epoch = (int)(elapsed / 280L);
        float gap = Math.max(1f, dp(1.1f));

        // Blue square "data" field rises from the bottom, column by column.
        for (int column = 0; column < columns; column++) {
            float x = column * pixelSize;
            float colOffset = (noise(column * 731 + 19) - .5f) * dp(55f)
                + (float)Math.sin(seconds * 2.2f + column * .79f) * dp(9f);
            float localFront = front + colOffset;

            for (int row = 0; row < rows; row++) {
                float y = row * pixelSize;
                float cellVariation = (noise(column * 997 + row * 59) - .5f) * dp(20f);
                if (y + pixelSize < localFront + cellVariation) continue;

                int id = column * 1637 + row * 313;
                float variant = noise(id + 417);
                if (variant < .07f) continue; // Intentional dark data gaps.

                int choice;
                if (variant < .15f) choice = 0;
                else if (variant < .35f) choice = 1;
                else if (variant < .56f) choice = 2;
                else if (variant < .76f) choice = 3;
                else if (variant < .91f) choice = 4;
                else if (variant < .965f) choice = 5;
                else if (variant < .991f) choice = 6;
                else choice = 7;

                // Sparse soft flicker, like digital data flowing upward.
                if (noise(id + epoch * 31) > .967f) choice = 7;
                else if (noise(id + epoch * 13) > .948f) choice = 5;

                // Light around the rising edge of the pixel wave.
                if (progress < 1f && Math.abs(y - localFront) < dp(26f)
                        && noise(id + 55) > .47f) {
                    choice = 5 + (int)(noise(id + 17) * 3f);
                    if (choice > 7) choice = 7;
                }

                square.setColor(TILES[choice]);
                float inset = gap * (.7f + noise(id + 223) * .85f);
                canvas.drawRect(x + inset, y + inset,
                    Math.min(width, x + pixelSize - inset),
                    Math.min(height, y + pixelSize - inset), square);
            }
        }

        // Larger drifting white and cyan squares. Each path wraps to the bottom.
        float cycleHeight = height + dp(220f);
        for (int i = 0; i < FRAGMENT_COUNT; i++) {
            float size = dp(10f + noise(i * 1069 + 11) * 27f);
            float x = noise(i * 947 + 31) * (width + size) - size * .3f;
            float speed = dp(85f + noise(i * 211 + 77) * 265f);
            float startingDepth = dp(15f + noise(i * 139 + 9) * 190f);
            float displacement = (seconds * speed
                    - (i % 3) * dp(4f)) % cycleHeight;
            float y = height + startingDepth - displacement;
            // Wrap any fragments that have already traveled offscreen.
            while (y < -size) y += cycleHeight;
            while (y > height + dp(215f)) y -= cycleHeight;
            if (y > height + size || y < -size) continue;

            // Ahead of the wave, just a few sparks announce the approaching rise.
            if (progress < 1f && y < front - dp(56f)) continue;

            int color = FRAGMENTS[(int)(noise(i * 173 + 5) * FRAGMENTS.length)];
            square.setColor(color);
            square.setAlpha(95 + (int)(noise(i * 397 + 19) * 156));
            canvas.drawRect(x, y, x + size, y + size, square);

            // Some pixels leave a sharp, shorter digital echo below themselves.
            if (i % 6 == 0) {
                square.setAlpha(65);
                float echoY = y + size + dp(8f);
                canvas.drawRect(x, echoY, x + size * .65f,
                    echoY + size * .7f, square);
            }
        }

        // Center darkening belongs to the animated layer, below the logo UI.
        canvas.drawRect(0, 0, width, height, centerShade);
        if (running) postInvalidateDelayed(FRAME_MS);
    }
}
