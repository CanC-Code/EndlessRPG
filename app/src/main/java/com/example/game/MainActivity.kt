package com.example.game
import android.content.res.AssetManager
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle

class MainActivity : AppCompatActivity() {
    init { System.loadLibrary("procedural_engine") }
    private external fun initAssetManager(am: AssetManager)
    private external fun initEngine()
    private external fun shutdownEngine()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initAssetManager(assets)
        initEngine()
        setContentView(GameSurfaceView(this))
    }
    override fun onDestroy() {
        super.onDestroy()
        shutdownEngine()
    }
}
