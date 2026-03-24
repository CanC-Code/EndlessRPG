package com.example.game

import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

/**
 * MainActivity serves as the lifecycle bridge between the Android OS 
 * and our high-performance C++ procedural engine.
 * * It coordinates the initialization of the Job System (logic), 
 * the Asset Manager (blueprints), and the GameSurfaceView (visuals).
 */
class MainActivity : AppCompatActivity() {

    // Load the 'procedural_engine' shared library on app startup.
    // This allows the Android OS to link our C++ logic to this Kotlin class.
    init {
        System.loadLibrary("procedural_engine")
    }

    // --- Native C++ Function Declarations ---

    /**
     * Links the Android Asset system to C++.
     * This is vital for the engine to read the .comp (Compute Shaders)
     * required for photorealistic grass generation.
     */
    private external fun initAssetManager(assetManager: AssetManager)

    /**
     * Boots the multithreaded Job System.
     * This initiates the 30 background computational processes to handle
     * world logic and growth patterns without causing frame-lag.
     */
    private external fun initEngine()

    /**
     * Safely tears down the engine's worker threads and releases 
     * GPU/Memory resources when the app is closed.
     */
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Initialize the Visual Surface.
        // GameSurfaceView handles its own native EGL connection internally
        // to render the procedural grass at high refresh rates.
        val gameView = GameSurfaceView(this)
        setContentView(gameView)

        // 2. Initialize the Asset Bridge.
        // We do this before initEngine so the workers can access asset-based logic.
        initAssetManager(assets)

        // 3. Boot the Engine.
        // This launches the 30 threads into the hardware-optimized Job System.
        initEngine()
    }

    override fun onPause() {
        super.onPause()
        // In a high-performance engine, you may want to signal the Job System
        // to throttle down here to save battery.
    }

    override fun onResume() {
        super.onResume()
        // Signal the Job System to resume full-speed logic processing.
    }

    override fun onDestroy() {
        super.onDestroy()

        // 4. Critical Cleanup.
        // Halts the 30 computational processes and joins threads to prevent
        // memory leaks or app-not-responding (ANR) errors on shutdown.
        shutdownEngine()
    }
}
