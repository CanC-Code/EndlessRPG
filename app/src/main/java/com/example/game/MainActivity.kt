package com.example.game

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {

    // Load the C++ engine library
    init {
        System.loadLibrary("procedural_engine")
    }

    // Native C++ functions
    private external fun initEngine()
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // In a full game, you would set a GLSurfaceView or Vulkan surface here
        // setContentView(GameSurfaceView(this))
        
        initEngine()
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
