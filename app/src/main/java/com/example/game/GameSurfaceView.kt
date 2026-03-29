package com.example.game

import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.widget.FrameLayout

class MainActivity : AppCompatActivity() {
    init { System.loadLibrary("procedural_engine") }
    
    private external fun initAssetManager(am: AssetManager)
    private external fun initEngine()
    private external fun shutdownEngine()
    
    external fun updateInput(mx: Float, my: Float, lx: Float, ly: Float, tp: Boolean, zoom: Float)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        initAssetManager(assets)
        initEngine()
        
        // Build a layout stack programmatically
        val rootLayout = FrameLayout(this)
        
        // 1. The C++ Engine Display (Bottom layer)
        val gameView = GameSurfaceView(this)
        rootLayout.addView(gameView)
        
        // 2. The Joystick UI (Top layer)
        val uiOverlay = JoystickOverlayView(this)
        rootLayout.addView(uiOverlay)
        
        setContentView(rootLayout)
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
