package com.example.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import kotlin.math.hypot
import kotlin.math.min

class GameSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    private external fun updateInput(mx: Float, my: Float, lx: Float, ly: Float, tp: Boolean, zoom: Float)
    private external fun surfaceCreated(surface: android.view.Surface)
    private external fun surfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()

    private var joyBaseX = 0f
    private var joyBaseY = 0f
    private var joyCurrentX = 0f
    private var joyCurrentY = 0f
    private val maxRadius = 150f
    private val deadzoneRadius = 20f

    // Standard touch/joystick drawing overrides here...

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Find the index of the joystick touch vs the camera panning touch
        
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                val deltaX = joyCurrentX - joyBaseX
                val deltaY = joyCurrentY - joyBaseY
                val distance = hypot(deltaX.toDouble(), deltaY.toDouble()).toFloat()

                var normX = 0f
                var normY = 0f

                // Prevent micro-drifting
                if (distance > deadzoneRadius) {
                    val clampedDist = min(distance, maxRadius)
                    normX = (deltaX / distance) * (clampedDist / maxRadius)
                    
                    // CRITICAL FIX: Invert Y here. Screen Y goes down, 3D world forward goes up/negative Z.
                    normY = -(deltaY / distance) * (clampedDist / maxRadius)
                }

                // Placeholder values for look delta X/Y and zoom which you will grab from the other pointer
                val lookDeltaX = 0f 
                val lookDeltaY = 0f 

                updateInput(normX, normY, lookDeltaX, lookDeltaY, true, 5.0f)
            }
            MotionEvent.ACTION_UP -> {
                // Snap joystick back
                joyCurrentX = joyBaseX
                joyCurrentY = joyBaseY
                updateInput(0f, 0f, 0f, 0f, true, 5.0f)
            }
        }
        return true
    }

    // Surface lifecycle...
    override fun surfaceCreated(holder: SurfaceHolder) { surfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { surfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
