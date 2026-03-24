package com.example.game

import android.content.Context
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView

class GameSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {

    init {
        holder.addCallback(this)
    }

    // Native JNI declarations to bridge the surface to C++
    private external fun setNativeSurface(surface: Surface)
    private external fun releaseNativeSurface()

    override fun surfaceCreated(holder: SurfaceHolder) {
        // Pass the physical surface handle to the C++ EGL bridge
        setNativeSurface(holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // Handle screen rotation or resizing here if necessary
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        // Ensure the GPU context is detached before the surface is gone
        releaseNativeSurface()
    }
}
