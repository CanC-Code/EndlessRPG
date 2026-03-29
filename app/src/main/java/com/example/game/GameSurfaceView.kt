package com.example.game

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView

class GameSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    
    private external fun surfaceCreated(surface: android.view.Surface)
    private external fun surfaceChanged(width: Int, height: Int)
    private external fun releaseNativeSurface()

    init {
        holder.addCallback(this)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceCreated(holder.surface) 
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, w: Int, h: Int) {
        surfaceChanged(w, h)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        releaseNativeSurface()
    }
}
