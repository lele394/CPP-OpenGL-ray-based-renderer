#version 430 core

out vec4 finalColor;

uniform vec2 resolution;
uniform vec3 camPos;
uniform vec3 camRot;
uniform float FOV;

uniform int chunkSize;
uniform ivec3 worldDim;



struct Voxel {
    uint material;
};

layout(std430, binding = 0) buffer VoxelData {
    Voxel voxels[];
};

const ivec3 CHUNK_SIZE = ivec3(32, 32, 32);
const float MAX_DIST = 1000.0;
const int MAX_STEPS = 3000;

// HAHAHA WELL ILL CHANGE THAT
const int NUM_COLORS = 40;

const vec3 voxelColors[NUM_COLORS] = vec3[NUM_COLORS](
    vec3(1.0, 0.0, 0.0),    // 1 red
    vec3(0.0, 1.0, 0.0),    // 2 green
    vec3(0.0, 0.0, 1.0),    // 3 blue
    vec3(1.0, 1.0, 0.0),    // 4 yellow
    vec3(1.0, 0.0, 1.0),    // 5 magenta
    vec3(0.0, 1.0, 1.0),    // 6 cyan
    vec3(1.0, 0.5, 0.0),    // 7 orange
    vec3(0.5, 0.0, 1.0),    // 8 purple
    vec3(0.0, 0.5, 1.0),    // 9 sky blue
    vec3(0.5, 1.0, 0.0),    // 10 lime green

    vec3(0.8, 0.2, 0.2),    // 11
    vec3(0.2, 0.8, 0.2),    // 12
    vec3(0.2, 0.2, 0.8),    // 13
    vec3(0.8, 0.8, 0.2),    // 14
    vec3(0.8, 0.2, 0.8),    // 15
    vec3(0.2, 0.8, 0.8),    // 16
    vec3(1.0, 0.75, 0.25),  // 17
    vec3(0.75, 0.25, 1.0),  // 18
    vec3(0.25, 1.0, 0.75),  // 19
    vec3(0.6, 0.4, 0.2),    // 20

    vec3(0.4, 0.6, 0.2),    // 21
    vec3(0.2, 0.4, 0.6),    // 22
    vec3(0.6, 0.2, 0.4),    // 23
    vec3(0.4, 0.2, 0.6),    // 24
    vec3(0.2, 0.6, 0.4),    // 25
    vec3(0.9, 0.1, 0.1),    // 26
    vec3(0.1, 0.9, 0.1),    // 27
    vec3(0.1, 0.1, 0.9),    // 28
    vec3(0.9, 0.9, 0.1),    // 29
    vec3(0.9, 0.1, 0.9),    // 30

    vec3(0.1, 0.9, 0.9),    // 31
    vec3(0.5, 0.5, 0.5),    // 32
    vec3(0.3, 0.3, 0.3),    // 33
    vec3(0.7, 0.7, 0.7),    // 34
    vec3(1.0, 0.6, 0.6),    // 35
    vec3(0.6, 1.0, 0.6),    // 36
    vec3(0.6, 0.6, 1.0),    // 37
    vec3(1.0, 1.0, 0.5),    // 38
    vec3(1.0, 0.5, 1.0),    // 39
    vec3(0.5, 1.0, 1.0)     // 40
);

vec3 getVoxelColor(uint materialId) {
    // IDs start at 1; array index at 0
    if (materialId == 0u || materialId > uint(NUM_COLORS)) {
        return vec3(0.2, 0.2, 0.2); // default gray
    }
    return voxelColors[int(materialId) - 1];
}





int floor_div(int a, int b) {
    return (a >= 0 ? a / b : ((a - b + 1) / b));
}

int worldToIndex3D(ivec3 pos) {

    ivec3 chunkCoord = ivec3(
        floor_div(pos.x, chunkSize),
        floor_div(pos.y, chunkSize),
        floor_div(pos.z, chunkSize)
    );

    if (any(lessThan(chunkCoord, ivec3(0))) || any(greaterThanEqual(chunkCoord, worldDim))) {
        return -1;
    }

    ivec3 local = ivec3(
        (pos.x % chunkSize + chunkSize) % chunkSize,
        (pos.y % chunkSize + chunkSize) % chunkSize,
        (pos.z % chunkSize + chunkSize) % chunkSize
    );

    int chunkIndex = chunkCoord.z * worldDim.y * worldDim.x + chunkCoord.y * worldDim.x + chunkCoord.x;
    int localIndex = local.z * chunkSize * chunkSize + local.y * chunkSize + local.x;
    return chunkIndex * chunkSize * chunkSize * chunkSize + localIndex;
}





mat3 getRotationMatrix(vec3 angles) {
    float cx = cos(angles.x), sx = sin(angles.x);
    float cy = cos(angles.y), sy = sin(angles.y);
    float cz = cos(angles.z), sz = sin(angles.z);

    mat3 rx = mat3(1, 0, 0,
                   0, cx, -sx,
                   0, sx, cx);
    mat3 ry = mat3(cy, 0, sy,
                   0, 1, 0,
                  -sy, 0, cy);
    mat3 rz = mat3(cz, -sz, 0,
                   sz,  cz, 0,
                   0,   0, 1);

    return rz * ry * rx;
}








bool intersectAABB(vec3 ro, vec3 rd, vec3 boxMin, vec3 boxMax, out float tNear, out float tFar) {
    // Used to check if ray will collide with world currently described
    vec3 invDir = 1.0 / rd;

    vec3 t0s = (boxMin - ro) * invDir;
    vec3 t1s = (boxMax - ro) * invDir;

    vec3 tsmaller = min(t0s, t1s);
    vec3 tbigger  = max(t0s, t1s);

    tNear = max(max(tsmaller.x, tsmaller.y), tsmaller.z);
    tFar  = min(min(tbigger.x, tbigger.y), tbigger.z);

    return tFar >= max(tNear, 0.0);
}




bool raymarch(vec3 ro, vec3 rd, out vec3 hitColor, out uint steps) {
    vec3 pos = floor(ro);
    vec3 deltaDist = abs(1.0 / rd);
    vec3 step = sign(rd);





    // Check if it at least will enter the world
    float tNear, tFar;
    // for AABB collision:
    vec3 boxMin = vec3(0);
    vec3 boxMax = vec3(worldDim * chunkSize);
    if (!intersectAABB(ro, rd, boxMin, boxMax, tNear, tFar)) {
        steps=0;
        return false; // immediately exit, ray misses the world
    }
    





    vec3 sideDist;
    sideDist.x = (rd.x > 0.0)
        ? (pos.x + 1.0 - ro.x) * deltaDist.x
        : (ro.x - pos.x) * deltaDist.x;
    sideDist.y = (rd.y > 0.0)
        ? (pos.y + 1.0 - ro.y) * deltaDist.y
        : (ro.y - pos.y) * deltaDist.y;
    sideDist.z = (rd.z > 0.0)
        ? (pos.z + 1.0 - ro.z) * deltaDist.z
        : (ro.z - pos.z) * deltaDist.z;


    for (int i = 0; i < MAX_STEPS; ++i) {
        ivec3 ipos = ivec3(pos);
        // int idx = worldToIndex(ipos); // Was used for single chunk
        int idx = worldToIndex3D(ipos);
        if (idx >= 0 && voxels[idx].material != 0u) {
            hitColor = getVoxelColor(voxels[idx].material);
            steps = i;
            return true;
        }

        if (sideDist.x < sideDist.y && sideDist.x < sideDist.z) {
            sideDist.x += deltaDist.x;
            pos.x += step.x;
        } else if (sideDist.y < sideDist.z) {
            sideDist.y += deltaDist.y;
            pos.y += step.y;
        } else {
            sideDist.z += deltaDist.z;
            pos.z += step.z;
        }

        if (length(pos - ro) > MAX_DIST) {
            steps = i;
            break;
        }
    }
    return false;
}















void main() {
    vec2 uv = (gl_FragCoord.xy / resolution) * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;

    float fovScale = tan(radians(FOV) * 0.5);
    vec3 rd = normalize(vec3(uv.x * fovScale, uv.y * fovScale, -1.0));
    vec3 ro = camPos;

    mat3 rot = getRotationMatrix(camRot);
    rd = rot * rd;

    vec3 color;
    uint steps;
    if (raymarch(ro, rd, color, steps)) {
        finalColor = vec4(color, 1.0);
    } else {
        color = rd.y < 0.0 ? vec3(135, 121, 100) / 255.0 : vec3(103, 159, 201) / 255.0;
        // color = vec3(0.0, 0.0, 0.0); // js want black rn
        finalColor = vec4(color, 1.0);
    }



    finalColor = vec4(float(steps)/MAX_STEPS, float(steps)/MAX_STEPS, float(steps)/MAX_STEPS, 1.0);

    // Flattened 3D to 2D, loop through voxels world data. All chunks
    // uint x = uint(gl_FragCoord.x);
    // uint y = uint(gl_FragCoord.y);
    // uint index = y * uint(resolution.x) + x;
    // // get voxel color
    // finalColor = vec4(getVoxelColor(voxels[index].material), 1.0);


}
