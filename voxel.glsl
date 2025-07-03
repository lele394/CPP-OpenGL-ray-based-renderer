#version 430 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

struct Voxel {
    uint material;
};

layout(std430, binding = 0) buffer VoxelData {
    Voxel voxels[];
};

// ====== CONSTANTS ======
const ivec3 worldDim = ivec3(16, 2, 16);  // in chunks
const int chunkSize = 32;

const float oceanLevel = 32.0;
const float scale = 80.0;
const int octaves = 4;
const float persistence = 0.5;
const float lacunarity = 2.0;

const float terrainHeightScale = 50.0;
const float terrainBaseHeight = oceanLevel - 20.0;

// ====== Hash-based noise ======
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < octaves; i++) {
        total += noise(p * frequency) * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    return total / maxValue;
}

// ====== Utility ======
int worldToIndex3D(ivec3 p) {
    return ((p.z * worldDim.y * worldDim.x) + (p.y * worldDim.x) + p.x) * (chunkSize * chunkSize * chunkSize);
}

void main() {
    ivec3 chunkCoord = ivec3(gl_WorkGroupID);
    ivec3 localID = ivec3(gl_LocalInvocationID);

    // Each thread covers multiple sub-blocks
    for (int ox = 0; ox < chunkSize; ox += 8)
    for (int oy = 0; oy < chunkSize; oy += 8)
    for (int oz = 0; oz < chunkSize; oz += 8) {

        ivec3 localPos = ivec3(ox, oy, oz) + localID;
        if (localPos.x >= chunkSize || localPos.y >= chunkSize || localPos.z >= chunkSize)
            continue;

        ivec3 globalPos = chunkCoord * chunkSize + localPos;

        int localIndex = localPos.z * chunkSize * chunkSize + localPos.y * chunkSize + localPos.x;
        int chunkBaseIndex = worldToIndex3D(chunkCoord);
        int globalIndex = chunkBaseIndex + localIndex;

        // ====== Terrain generation ======
        float nx = float(globalPos.x) / scale;
        float nz = float(globalPos.z) / scale;

        float elevation = fbm(vec2(nx, nz));
        float height = elevation * terrainHeightScale + terrainBaseHeight;

        uint material = 0u;
        if (float(globalPos.y) < height - 5.0) {
            material = 1u;  // stone
        } else if (float(globalPos.y) < height - 1.0) {
            material = 2u;  // dirt
        } else if (float(globalPos.y) < height) {
            material = 3u;  // grass
        } else if (float(globalPos.y) < oceanLevel) {
            material = 4u;  // water
        } else {
            material = 0u;  // air
        }

        voxels[globalIndex].material = material;
    }
}
