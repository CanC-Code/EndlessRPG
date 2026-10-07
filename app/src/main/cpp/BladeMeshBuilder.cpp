#include "BladeMeshBuilder.h"

int build_frame_grass(const std::vector<GrassTile>& tiles,
                      const CameraView& cam,
                      float windTime,
                      BladeVertex* outVerts,
                      int maxVerts)
{
    (void)tiles; (void)cam; (void)windTime; (void)outVerts; (void)maxVerts;
    return 0;  // skeleton — meshing lands in commit 4
}
