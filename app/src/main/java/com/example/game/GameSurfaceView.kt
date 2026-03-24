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

class GameSurfaceView(context: Context) : FrameLayout(context), SurfaceHolder.Callback {
    private external fun onSurfaceCreated(surface: android.view.Surface)
    private external fun onSurfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()
    
    // UPDATED JNI: Now passes camera mode and zoom data
    private external fun updateInput(moveX: Float, moveY: Float, lookDX: Float, lookDY: Float, isThirdPerson: Boolean, zoom: Float)

    private val surfaceView = SurfaceView(context)

    private var leftPointerId = -1
    private var rightPointerId = -1
    
    private val maxRadius = 180f
    private var joyBaseX = 0f
    private var joyBaseY = 0f
    private var joyCurrentX = 0f
    private var joyCurrentY = 0f
    private var moveX = 0f
    private var moveY = 0f
    private var lastLookX = 0f
    private var lastLookY = 0f

    // --- NEW: Camera State ---
    private var isThirdPerson = false
    private var cameraZoom = 5.0f

    // --- NEW: Pinch-to-Zoom Detector ---
    private val scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            if (isThirdPerson) {
                // If the user pinches OUT, scaleFactor > 1, so zoom decreases (moves closer)
                cameraZoom /= detector.scaleFactor 
                if (cameraZoom < 2.0f) cameraZoom = 2.0f
                if (cameraZoom > 20.0f) cameraZoom = 20.0f
            }
            return true
        }
    })

    // UI Styles
    private val basePaint = Paint().apply { color = Color.argb(40, 255, 255, 255); style = Paint.Style.FILL; isAntiAlias = true }
    private val baseOutlinePaint = Paint().apply { color = Color.argb(80, 255, 255, 255); style = Paint.Style.STROKE; strokeWidth = 6f; isAntiAlias = true }
    private val knobPaint = Paint().apply { color = Color.argb(220, 255, 255, 255); style = Paint.Style.FILL; isAntiAlias = true }
    
    // UI Button Styles
    private val buttonPaint = Paint().apply { color = Color.argb(180, 40, 40, 40); style = Paint.Style.FILL; isAntiAlias = true }
    private val buttonTextPaint = Paint().apply { color = Color.WHITE; textSize = 45f; textAlign = Paint.Align.CENTER; isAntiAlias = true }

    init {
        surfaceView.holder.addCallback(this)
        addView(surfaceView)
        setWillNotDraw(false) 
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        joyBaseX = w * 0.15f
        if (joyBaseX < 250f) joyBaseX = 250f 
        joyBaseY = h - joyBaseX
        joyCurrentX = joyBaseX
        joyCurrentY = joyBaseY
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Feed touch events to the zoom detector first
        scaleDetector.onTouchEvent(event)

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
                // --- NEW: Check if the user tapped the View Toggle Button ---
                if (x > 50f && x < 400f && y > 50f && y < 160f) {
                    isThirdPerson = !isThirdPerson
                    invalidate()
                    return true 
                }

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
                    } else if (id == rightPointerId && !scaleDetector.isInProgress) {
                        // Only rotate camera if we aren't currently pinching to zoom
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
        
        // Push all state to C++
        updateInput(moveX, moveY, lookDX, lookDY, isThirdPerson, cameraZoom)
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
        moveX = -(dx / maxRadius)
        moveY = -(dy / maxRadius) 
        invalidate()
    }

    override fun dispatchDraw(canvas: Canvas) {
        super.dispatchDraw(canvas) 
        
        // Draw Joystick
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, basePaint)
        canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, baseOutlinePaint)
        canvas.drawCircle(joyCurrentX, joyCurrentY, maxRadius * 0.35f, knobPaint)

        // --- NEW: Draw Toggle View Button ---
        canvas.drawRoundRect(50f, 50f, 400f, 160f, 20f, 20f, buttonPaint)
        val modeText = if (isThirdPerson) "3rd Person" else "1st Person"
        canvas.drawText(modeText, 225f, 120f, buttonTextPaint)
    }

    override fun surfaceCreated(holder: SurfaceHolder) { onSurfaceCreated(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) { onSurfaceChanged(w, h) }
    override fun surfaceDestroyed(holder: SurfaceHolder) { releaseNativeSurface() }
}
