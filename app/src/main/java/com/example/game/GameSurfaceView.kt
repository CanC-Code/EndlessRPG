package com.example.game

import android.content.Context
import android.view.SurfaceView
import android.view.SurfaceHolder
import android.view.MotionEvent
import kotlin.math.hypot

class GameSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    private external fun onSurfaceCreated(surface: android.view.Surface)
    private external fun onSurfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()
    
    // New JNI bridge for touch controls
    private external fun updateInput(moveX: Float, moveY: Float, lookDX: Float, lookDY: Float)

    private var leftPointerId = -1
    private var rightPointerId = -1
    
    private var joyStartX = 0f
    private var joyStartY = 0f
    private var moveX = 0f
    private var moveY = 0f
    
    private var lastLookX = 0f
    private var lastLookY = 0f

    init {
        holder.addCallback(this)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val action = event.actionMasked
        val pointerIndex = event.actionIndex
        val pointerId = event.getPointerId(pointerIndex)
        
        val x = event.getX(pointerIndex)
        val y = event.getY(pointerIndex)
        val halfWidth = width / 2f

        var lookDX = 0f
        var lookDY = 0f

        when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                if (x < halfWidth && leftPointerId == -1) {
                    leftPointerId = pointerId
                    joyStartX = x
                    joyStartY = y
                } else if (x >= halfWidth && rightPointerId == -1) {
                    rightPointerId = pointerId
                    lastLookX = x
                    lastLookY = y
                }
            }
            MotionEvent.ACTION_MOVE -> {
                for (i in 0 until event.pointerCount) {
                    val id = event.getPointerId(i)
                    val px = event.getX(i)
                    val py = event.getY(i)
                    
                    if (id == leftPointerId) {
                        val maxRadius = 200f
                        var dx = px - joyStartX
                        var dy = py - joyStartY
                        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
                        
                        // Clamp the virtual thumbstick to a circular radius
                        if (dist > maxRadius) {
                            dx = (dx / dist) * maxRadius
                            dy = (dy / dist) * maxRadius
                        }
                        
                        moveX = dx / maxRadius
                        // Invert Y so pushing UP moves you FORWARD
                        moveY = -(dy / maxRadius) 
                    } else if (id == rightPointerId) {
                        lookDX += px - lastLookX
                        lookDY += py - lastLookY
                        lastLookX = px
                        lastLookY = py
                    }
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                if (pointerId == leftPointerId) {
                    leftPointerId = -1
                    moveX = 0f
                    moveY = 0f
                } else if (pointerId == rightPointerId) {
                    rightPointerId = -1
                }
            }
        }
        
        // Push the data to the C++ Engine immediately
        updateInput(moveX, moveY, lookDX, lookDY)
        return true
    }

    override fun surfaceCreated(holder: SurfaceHolder) { onSurfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { onSurfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
