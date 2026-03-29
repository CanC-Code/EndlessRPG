add_library(procedural_engine SHARED
    # Add the new file here
    NativeEngine.cpp
    
    # Existing files
    Engine.cpp
    Renderer.cpp
    Character.cpp
    AssetManager.cpp
    EGLCore.cpp
    RenderLoop.cpp
)

# Ensure you are linking the Android library for the AssetManager
target_link_libraries(procedural_engine
    android
    log
    GLESv3
)
