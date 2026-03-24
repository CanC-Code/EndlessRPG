package com.example.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.SurfaceView
import android.view.SurfaceHolder
import android.view.MotionEvent
import android.widget.FrameLayout
import kotlin.math.hypot

class GameSurfaceView(context: Context) : FrameLayout(context), SurfaceHolder.Callback {
    private external fun onSurfaceCreated(surface: android.view.Surface)
    private external fun onSurfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()
    private external fun updateInput(moveX: Float, moveY: Float, lookDX: Float, lookDY: Float)

    // The dedicated surface for the C++ OpenGL engine
    private val surfaceView = SurfaceView(context)

    private var leftPointerId = -1
    private var rightPointerId = -1
    
    // Joystick rendering variables
    private var joyStartX = 0f
    private var joyStartY = 0f
    private var joyCurrentX = 0f
    private var joyCurrentY = 0f
    private var isJoystickActive = false
    private val maxRadius = 200f
    
    private var moveX = 0f
    private var moveY = 0f
    
    private var lastLookX = 0f
    private var lastLookY = 0f

    // UI Styles for the thumbstick
    private val basePaint = Paint().apply {
        color = Color.argb(80, 200, 200, 200) // Semi-transparent grey
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val knobPaint = Paint().apply {
        color = Color.argb(180, 255, 255, 255) // Solid white
        style = Paint.Style.FILL
        isAntiAlias = true
    }

    init {
        // Set up the OpenGL surface layer
        surfaceView.holder.addCallback(this)
        addView(surfaceView)
        
        // Tells Android this FrameLayout will handle its own custom UI drawing
        setWillNotDraw(false) 
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
                    isJoystickActive = true
                    joyStartX = x
                    joyStartY = y
                    joyCurrentX = x
                    joyCurrentY = y
                    invalidate() // Trigger UI redraw
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
                        var dx = px - joyStartX
                        var dy = py - joyStartY
                        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
                        
                        // Clamp the visual knob to the base radius
                        if (dist > maxRadius) {
                            dx = (dx / dist) * maxRadius
                            dy = (dy / dist) * maxRadius
                        }
                        
                        joyCurrentX = joyStartX + dx
                        joyCurrentY = joyStartY + dy
                        
                        moveX = dx / maxRadius
                        moveY = -(dy / maxRadius) 
                        invalidate() // Trigger UI redraw
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
                    isJoystickActive = false
                    moveX = 0f
                    moveY = 0f
                    invalidate() // Clear the joystick from the screen
                } else if (pointerId == rightPointerId) {
                    rightPointerId = -1
                }
            }
        }
        
        updateInput(moveX, moveY, lookDX, lookDY)
        return true
    }

    // This runs on top of the C++ OpenGL render, drawing the UI
    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas) 
        
        if (isJoystickActive) {
            canvas.drawCircle(joyStartX, joyStartY, maxRadius, basePaint)
            canvas.drawCircle(joyCurrentX, joyCurrentY, 70f, knobPaint)
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) { onSurfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { onSurfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
