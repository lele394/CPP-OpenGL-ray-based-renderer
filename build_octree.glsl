#version 430 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

uniform ivec3 worldDim;
uniform int chunkSize;

struct Voxel {
    uint material;
};

layout(std430, binding = 0) buffer RawVoxelData {
    Voxel voxels[];
};

layout(std430, binding = 1) buffer OctreeData {
    uint octreeNodes[];
};

// Derived constants
const int MAX_MATERIAL = 4;

int floor_div(int a, int b) {
    return (a >= 0 ? a / b : ((a - b + 1) / b));
}

int worldToChunkIndex(ivec3 chunkCoord) {
    return chunkCoord.z * worldDim.y * worldDim.x + chunkCoord.y * worldDim.x + chunkCoord.x;
}

// Compute local voxel index inside chunk
int localVoxelIndex(ivec3 localPos) {
    return localPos.z * chunkSize * chunkSize + localPos.y * chunkSize + localPos.x;
}

// Compute per-chunk offset
int voxelChunkOffset(int chunkIndex) {
    return chunkIndex * (chunkSize * chunkSize * chunkSize);
}

int octreeChunkOffset(int chunkIndex, int octreeNodesPerChunk) {
    return chunkIndex * octreeNodesPerChunk;
}

// Find most frequent material in a block
uint getMostFrequentMaterial(int chunkIndex, ivec3 regionMin, int regionSize) {
    int counts[5] = int[5](0,0,0,0,0);
    int chunkOffset = voxelChunkOffset(chunkIndex);

    for (int z = 0; z < regionSize; ++z)
    for (int y = 0; y < regionSize; ++y)
    for (int x = 0; x < regionSize; ++x) {
        ivec3 localPos = regionMin + ivec3(x,y,z);
        if (any(greaterThanEqual(localPos, ivec3(chunkSize))))
            continue;

        int localIdx = localVoxelIndex(localPos);
        uint mat = voxels[chunkOffset + localIdx].material;
        if (mat <= MAX_MATERIAL)
            counts[mat]++;
    }

    int maxMat = 0;
    for (int i = 1; i <= MAX_MATERIAL; ++i)
        if (counts[i] > counts[maxMat])
            maxMat = i;

    return uint(maxMat);
}

// Precompute octree parameters for CHUNK_SIZE=32
const int levels = int(log2(32));
const int octreeNodesPerChunk = int( (pow(8, levels+1) - 1) / 7 );

void buildOctreeForChunk(ivec3 chunkCoord) {
    int chunkIndex = worldToChunkIndex(chunkCoord);
    int writeBase = octreeChunkOffset(chunkIndex, octreeNodesPerChunk);

    int writeIndex = writeBase;

    // Build pyramid from coarse to fine
    for (int level = 0; level <= levels; ++level) {
        int size = chunkSize >> level;
        int step = size;

        for (int z = 0; z < chunkSize; z += step)
        for (int y = 0; y < chunkSize; y += step)
        for (int x = 0; x < chunkSize; x += step) {
            octreeNodes[writeIndex++] = getMostFrequentMaterial(chunkIndex, ivec3(x,y,z), step);
        }
    }
}

void main() {
    ivec3 chunkCoord = ivec3(gl_GlobalInvocationID);

    if (any(greaterThanEqual(chunkCoord, worldDim)))
        return;

    buildOctreeForChunk(chunkCoord);
}
