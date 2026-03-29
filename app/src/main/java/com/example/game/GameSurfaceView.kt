package com.example.game

import android.content.Context
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
    
    // Adding camera look variables
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var lookDeltaX = 0f
    private var lookDeltaY = 0f

    init {
        holder.addCallback(this)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                joyBaseX = event.x
                joyBaseY = event.y
                joyCurrentX = event.x
                joyCurrentY = event.y
                lastTouchX = event.x
                lastTouchY = event.y
            }
            MotionEvent.ACTION_MOVE -> {
                joyCurrentX = event.x
                joyCurrentY = event.y
                
                // Calculate movement
                val dx = joyCurrentX - joyBaseX
                val dy = joyCurrentY - joyBaseY
                val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
                
                var normX = 0f
                var normY = 0f
                if (dist > 20f) {
                    val scale = min(dist, 150f) / 150f
                    normX = (dx / dist) * scale
                    normY = -(dy / dist) * scale // Y inversion fixed
                }

                // Calculate Look delta (simple generic touch for right now)
                lookDeltaX = event.x - lastTouchX
                lookDeltaY = event.y - lastTouchY
                lastTouchX = event.x
                lastTouchY = event.y

                updateInput(normX, normY, lookDeltaX, lookDeltaY, true, 15f)
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                updateInput(0f, 0f, 0f, 0f, true, 15f)
            }
        }
        return true
    }

    override fun surfaceCreated(holder: SurfaceHolder) { surfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { surfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
