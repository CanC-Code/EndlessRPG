package com.example.game

import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {

    init { 
        System.loadLibrary("procedural_engine") 
    }

    private external fun initAssetManager(assetManager: AssetManager)
    private external fun initEngine()
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Initialize Asset Bridge FIRST to prevent null-pointer in native layer
        initAssetManager(assets)
        
        // 2. Boot the Thread Pool / Job System
        initEngine()
        
        // 3. Create the visual surface ONLY AFTER logic and memory are ready
        setContentView(GameSurfaceView(this))
    }

    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
