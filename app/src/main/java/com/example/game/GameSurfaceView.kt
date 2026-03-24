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

    private val surfaceView = SurfaceView(context)

    private var leftPointerId = -1
    private var rightPointerId = -1
    
    // Fixed joystick variables
    private val maxRadius = 180f
    private var joyBaseX = 0f
    private var joyBaseY = 0f
    private var joyCurrentX = 0f
    private var joyCurrentY = 0f
    
    private var moveX = 0f
    private var moveY = 0f
    
    private var lastLookX = 0f
    private var lastLookY = 0f

    // High-quality UI Styles
    private val basePaint = Paint().apply {
        color = Color.argb(40, 255, 255, 255) // Soft semi-transparent white
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val baseOutlinePaint = Paint().apply {
        color = Color.argb(80, 255, 255, 255) // Distinct rim outline
        style = Paint.Style.STROKE
        strokeWidth = 6f
        isAntiAlias = true
    }
    private val knobPaint = Paint().apply {
        color = Color.argb(220, 255, 255, 255) // Solid bright white knob
        style = Paint.Style.FILL
        isAntiAlias = true
    }

    init {
        surfaceView.holder.addCallback(this)
        addView(surfaceView)
        setWillNotDraw(false) 
    }

    // Calculate the permanent position of the joystick when the screen size is known
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        joyBaseX = w * 0.15f
        if (joyBaseX < 250f) joyBaseX = 250f // Keep it safely away from the edge
        joyBaseY = h - joyBaseX
        
        joyCurrentX = joyBaseX
        joyCurrentY = joyBaseY
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
                    updateJoystick(x, y)
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
                        updateJoystick(px, py)
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
                    // Snap the knob cleanly back to the center
                    joyCurrentX = joyBaseX
                    joyCurrentY = joyBaseY
                    moveX = 0f
                    moveY = 0f
                    invalidate()
                } else if (pointerId == rightPointerId) {
                    rightPointerId = -1
                }
            }
        }
        
        updateInput(moveX, moveY, lookDX, lookDY)
        return true
    }

    private fun updateJoystick(px: Float, py: Float) {
        var dx = px - joyBaseX
        var dy = py - joyBaseY
        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
        
        if (dist > maxRadius) {
            dx = (dx / dist) * maxRadius
            dy = (dy / dist) * maxRadius
        }
        
        joyCurrentX = joyBaseX + dx
        joyCurrentY = joyBaseY + dy
        
        // FIXED: moveX is now INVERTED to solve the left/right flip issue
        moveX = -(dx / maxRadius)
        moveY = -(dy / maxRadius) 
        invalidate()
    }

    // Runs on top of the C++ OpenGL render
    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas) 
        
        // Constantly draw the base UI
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, basePaint)
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, baseOutlinePaint)
        
        // Draw the moving knob
        canvas.drawCircle(joyCurrentX, joyCurrentY, maxRadius * 0.35f, knobPaint)
    }

    override fun surfaceCreated(holder: SurfaceHolder) { onSurfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { onSurfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
