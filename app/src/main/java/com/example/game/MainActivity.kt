package com.example.game

import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

/**
 * MainActivity serves as the lifecycle bridge between the Android OS 
 * and our high-performance C++ procedural engine.
 */
class MainActivity : AppCompatActivity() {

    // Load the 'procedural_engine' shared library on app startup
    init {
        System.loadLibrary("procedural_engine")
    }

    // --- Native C++ Function Declarations ---
    
    // Links the Android Asset system to C++ (Critical for loading shaders)
    private external fun initAssetManager(assetManager: AssetManager)
    
    // Boots the Job System and starts the 30 computational processes
    private external fun initEngine()
    
    // Safely tears down threads and releases GPU memory
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Initialize the Asset Bridge FIRST so the engine can load its "logic"
        initAssetManager(assets)

        // 2. Initialize the Engine and the multi-threaded Job System
        initEngine()
        
        // Note: For the visual component, we will later add:
        // setContentView(GameSurfaceView(this))
    }

    override fun onDestroy() {
        super.onDestroy()
        
        // Ensure all 30 processes are stopped and threads joined to avoid ghost memory leaks
        shutdownEngine()
    }
}
