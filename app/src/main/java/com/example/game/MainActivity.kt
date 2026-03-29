package com.example.game

import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
    
    // Load the native library
    init { 
        System.loadLibrary("procedural_engine") 
    }

    // JNI Declarations
    private external fun initAssetManager(am: AssetManager)
    private external fun initEngine()
    private external fun shutdownEngine()
    
    // ADDED: This must exist for GameSurfaceView to call it without crashing
    external fun updateInput(mx: Float, my: Float, lx: Float, ly: Float, tp: Boolean, zoom: Float)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Initialize non-GL logic
        initAssetManager(assets)
        initEngine()
        
        // 2. Set the view. 
        // Note: OpenGL initialization happens LATER inside the SurfaceView's thread.
        setContentView(GameSurfaceView(this))
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
