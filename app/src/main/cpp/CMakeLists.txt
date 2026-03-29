add_library(procedural_engine SHARED
    NativeEngine.cpp
    Renderer.cpp
    Character.cpp
    AssetManager.cpp
    EGLCore.cpp
    RenderLoop.cpp
    # Notice Engine.cpp is GONE from this list
)

target_link_libraries(procedural_engine
    android
    log
    GLESv3
)
