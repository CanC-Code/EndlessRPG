package com.example.game
import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
    init { System.loadLibrary("procedural_engine") }
    private external fun initAssetManager(assetManager: AssetManager)
    private external fun initEngine()
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(GameSurfaceView(this))
        initAssetManager(assets)
        initEngine()
    }
    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
