override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
        MotionEvent.ACTION_MOVE -> {
            val dx = event.getX(0) - joyBaseX
            val dy = event.getY(0) - joyBaseY
            val dist = hypot(dx, dy)
            
            var normX = 0f
            var normY = 0f
            if (dist > 20f) {
                val scale = min(dist, 150f) / 150f
                normX = (dx / dist) * scale
                normY = -(dy / dist) * scale // Corrected Inversion
            }
            updateInput(normX, normY, lookDeltaX, lookDeltaY, true, 15f)
        }
    }
    return true
}
