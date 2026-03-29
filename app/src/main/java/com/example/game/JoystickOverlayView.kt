package com.example.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot
import kotlin.math.min

class JoystickOverlayView(context: Context) : View(context) {

    private val paintBase = Paint().apply { color = Color.argb(80, 255, 255, 255); style = Paint.Style.FILL }
    private val paintThumb = Paint().apply { color = Color.argb(150, 255, 255, 255); style = Paint.Style.FILL }

    private var leftPointerId = -1
    private var rightPointerId = -1

    // Left Joy Logic
    private var joyActive = false
    private var joyBaseX = 0f
    private var joyBaseY = 0f
    private var joyCurrX = 0f
    private var joyCurrY = 0f
    private val maxRadius = 150f

    // Right Camera Logic
    private var lastLookX = 0f
    private var lastLookY = 0f

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val action = event.actionMasked
        val pointerIndex = event.actionIndex
        val pointerId = event.getPointerId(pointerIndex)
        val x = event.getX(pointerIndex)
        val y = event.getY(pointerIndex)

        val halfScreen = width / 2f

        when (action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                if (x < halfScreen && leftPointerId == -1) {
                    leftPointerId = pointerId
                    joyActive = true
                    joyBaseX = x
                    joyBaseY = y
                    joyCurrX = x
                    joyCurrY = y
                } else if (x >= halfScreen && rightPointerId == -1) {
                    rightPointerId = pointerId
                    lastLookX = x
                    lastLookY = y
                }
            }
            MotionEvent.ACTION_MOVE -> {
                var normX = 0f
                var normY = 0f
                var lookDeltaX = 0f
                var lookDeltaY = 0f

                for (i in 0 until event.pointerCount) {
                    val pId = event.getPointerId(i)
                    val px = event.getX(i)
                    val py = event.getY(i)

                    if (pId == leftPointerId) {
                        val dx = px - joyBaseX
                        val dy = py - joyBaseY
                        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
                        
                        val clampedDist = min(dist, maxRadius)
                        val ratio = if (dist > 0) clampedDist / dist else 0f
                        
                        joyCurrX = joyBaseX + dx * ratio
                        joyCurrY = joyBaseY + dy * ratio

                        if (dist > 20f) { // Deadzone
                            normX = (joyCurrX - joyBaseX) / maxRadius
                            normY = -((joyCurrY - joyBaseY) / maxRadius) // Invert Y
                        }
                    } else if (pId == rightPointerId) {
                        lookDeltaX = px - lastLookX
                        lookDeltaY = py - lastLookY
                        lastLookX = px
                        lastLookY = py
                    }
                }

                (context as MainActivity).updateInput(normX, normY, lookDeltaX, lookDeltaY, true, 15f)
                invalidate() // Redraw the joystick
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                if (pointerId == leftPointerId) {
                    leftPointerId = -1
                    joyActive = false
                    (context as MainActivity).updateInput(0f, 0f, 0f, 0f, true, 15f)
                } else if (pointerId == rightPointerId) {
                    rightPointerId = -1
                }
                invalidate()
            }
        }
        return true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (joyActive) {
            canvas.drawCircle(joyBaseX, joyBaseY, maxRadius, paintBase)
            canvas.drawCircle(joyCurrX, joyCurrY, maxRadius * 0.4f, paintThumb)
        }
    }
}
