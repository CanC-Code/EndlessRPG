package com.example.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.ScaleGestureDetector
import android.view.SurfaceView
import android.view.SurfaceHolder
import android.view.MotionEvent
import android.widget.FrameLayout
import kotlin.math.hypot
import kotlin.math.pow
import kotlin.math.sign

class GameSurfaceView(context: Context) : FrameLayout(context), SurfaceHolder.Callback {
    private external fun onSurfaceCreated(surface: android.view.Surface)
    private external fun onSurfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()
    private external fun updateInput(moveX: Float, moveY: Float, lookDX: Float, lookDY: Float, isThirdPerson: Boolean, zoom: Float)

    private val surfaceView = SurfaceView(context)

    private var leftPointerId = -1
    private var rightPointerId = -1
    
    // --- ERGONOMIC ADJUSTMENTS ---
    private val maxRadius = 130f // Reduced from 180f for better ergonomics
    private var joyBaseX = 0f
    private var joyBaseY = 0f
    private var joyCurrentX = 0f
    private var joyCurrentY = 0f
    
    private var moveX = 0f
    private var moveY = 0f
    private var lastLookX = 0f
    private var lastLookY = 0f

    private var isThirdPerson = false
    private var cameraZoom = 8.0f // Slightly further default for better scale

    private val scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            if (isThirdPerson) {
                cameraZoom /= detector.scaleFactor 
                cameraZoom = cameraZoom.coerceIn(2.0f, 30.0f)
            }
            return true
        }
    })

    // --- REFINED UI STYLES ---
    private val basePaint = Paint().apply {
        color = Color.argb(30, 255, 255, 255)
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val baseOutlinePaint = Paint().apply {
        color = Color.argb(60, 255, 255, 255)
        style = Paint.Style.STROKE
        strokeWidth = 4f // Thinner, more professional line
        isAntiAlias = true
    }
    private val knobPaint = Paint().apply {
        color = Color.argb(200, 255, 255, 255)
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val buttonPaint = Paint().apply { 
        color = Color.argb(160, 20, 20, 20)
        style = Paint.Style.FILL
        isAntiAlias = true 
    }
    private val buttonTextPaint = Paint().apply { 
        color = Color.WHITE
        textSize = 40f
        textAlign = Paint.Align.CENTER
        isAntiAlias = true 
    }

    init {
        surfaceView.holder.addCallback(this)
        addView(surfaceView)
        setWillNotDraw(false) 
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // Positioned 15% from left, 15% from bottom
        joyBaseX = w * 0.15f
        joyBaseY = h - (h * 0.15f)
        joyCurrentX = joyBaseX
        joyCurrentY = joyBaseY
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)

        val action = event.actionMasked
        val pointerIndex = event.actionIndex
        val pointerId = event.getPointerId(pointerIndex)
        val x = event.getX(pointerIndex)
        val y = event.getY(pointerIndex)

        var lookDX = 0f
        var lookDY = 0f

        when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                // Button Detection (Top Left)
                if (x < 450f && y < 200f) {
                    isThirdPerson = !isThirdPerson
                    invalidate()
                    return true 
                }

                if (x < width / 2f && leftPointerId == -1) {
                    leftPointerId = pointerId
                    updateJoystick(x, y)
                } else if (x >= width / 2f && rightPointerId == -1) {
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
                    } else if (id == rightPointerId && !scaleDetector.isInProgress) {
                        // --- CAMERA SMOOTHING CURVE ---
                        // Applying a mild power curve makes small movements more precise
                        val rawDX = px - lastLookX
                        val rawDY = py - lastLookY
                        
                        lookDX += rawDX.pow(1.2f * sign(rawDX)) // Quadratic sensitivity
                        lookDY += rawDY.pow(1.2f * sign(rawDY))
                        
                        lastLookX = px
                        lastLookY = py
                    }
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                if (pointerId == leftPointerId) {
                    leftPointerId = -1
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
        
        updateInput(moveX, moveY, lookDX, lookDY, isThirdPerson, cameraZoom)
        return true
    }

    private fun updateJoystick(px: Float, py: Float) {
        var dx = px - joyBaseX
        var dy = py - joyBaseY
        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
        
        // Deadzone check (ignore tiny accidental movements)
        if (dist < 10f) {
            moveX = 0f
            moveY = 0f
            return
        }

        if (dist > maxRadius) {
            dx = (dx / dist) * maxRadius
            dy = (dy / dist) * maxRadius
        }
        
        joyCurrentX = joyBaseX + dx
        joyCurrentY = joyBaseY + dy
        
        // Inverted DX for correct movement vector
        moveX = -(dx / maxRadius)
        moveY = -(dy / maxRadius) 
        invalidate()
    }

    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas) 
        
        // Joystick Base
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, basePaint)
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, baseOutlinePaint)
        
        // Knob
        canvas.drawCircle(joyCurrentX, joyCurrentY, maxRadius * 0.4f, knobPaint)

        // Refined Toggle Button
        canvas.drawRoundRect(60f, 60f, 410f, 170f, 30f, 30f, buttonPaint)
        val modeText = if (isThirdPerson) "VIEW: 3RD" else "VIEW: 1ST"
        canvas.drawText(modeText, 235f, 130f, buttonTextPaint)
    }

    override fun surfaceCreated(holder: SurfaceHolder) { onSurfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { onSurfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
