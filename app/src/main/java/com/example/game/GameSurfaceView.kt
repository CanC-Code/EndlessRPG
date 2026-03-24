package com.example.game
import android.content.Context
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView

class GameSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {
    init { holder.addCallback(this) }
    private external fun setNativeSurface(surface: Surface)
    private external fun releaseNativeSurface()
    override fun surfaceCreated(h: SurfaceHolder) { setNativeSurface(h.surface) }
    override fun surfaceChanged(h: SurfaceHolder, f: Int, w: Int, h2: Int) {}
    override fun surfaceDestroyed(h: SurfaceHolder) { releaseNativeSurface() }
}
