#version 430 core

out vec4 finalColor;

uniform vec2 resolution;
uniform vec3 camPos;
uniform vec3 camRot;
uniform float FOV;

uniform int chunkSize;
uniform ivec3 worldDim;

uniform int RENDER_DEBUG;

struct Voxel {
    uint material;
};

layout(std430, binding = 0) buffer VoxelData {
    Voxel voxels[];
};

const ivec3 CHUNK_SIZE = ivec3(32, 32, 32);
const float MAX_DIST = 10000.0;
const int MAX_STEPS = 1024;




struct Material {
    vec3 color;
    float opacity;
};



const int NUM_MATERIALS = 4;

const Material voxelMaterials[NUM_MATERIALS] = Material[NUM_MATERIALS](
    Material(vec3(0.5, 0.5, 0.5), 1.0),   // stone
    Material(vec3(0.4, 0.25, 0.1), 1.0),  // dirt
    Material(vec3(0.055,0.639,0.231), 1.0),    // grass
    Material(vec3(0.2, 0.4, 1.0), 0.15)    // water
);



// For now AIR is defined here, ie the empty cell
const Material AIR = Material(vec3(1.0, 1.0, 1.0), 0.0);
Material getVoxelMaterial(uint materialId) {
    if (materialId == 0u) {
        return AIR;
    }
    if (materialId > uint(NUM_MATERIALS)) {
        return Material(vec3(0.2, 0.2, 0.2), 1.0); // default gray
    }
    return voxelMaterials[int(materialId) - 1];
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

    bool result =  tFar >= max(tNear, 0.0);
    tFar = tFar + 0.001; // SOOOOO I need to add epsilon or there's a conflict in the outbound check that gives me a visual glitch
    return result;
}



// === Beer-Lambert absorption + background composition ===
bool raymarch(vec3 ro, vec3 rd, out vec3 accumulatedColor, out float transparency, out uint steps, out vec3 impactPosition) {
    vec3 pos = floor(ro);
    float tNear, tFar;
    vec3 boxMin = vec3(0);
    vec3 boxMax = vec3(worldDim * chunkSize);

    if (!intersectAABB(ro, rd, boxMin, boxMax, tNear, tFar)) {
        accumulatedColor = vec3(0.0);
        transparency = 1.0;
        steps = 0;
        impactPosition = pos;
        return false;
    }

    float tStart = max(tNear, 0.0);
    vec3 roStart = ro + rd * tStart;
    pos = floor(roStart);
    vec3 step = sign(rd);
    vec3 deltaDist = abs(1.0 / rd);

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

    accumulatedColor = vec3(0.0);
    transparency = 1.0;

    float last_t = tStart;

    for (int i = 0; i < MAX_STEPS; ++i) {
        ivec3 ipos = ivec3(pos);
        int idx = worldToIndex3D(ipos);

        float t = min(min(sideDist.x, sideDist.y), sideDist.z);

        if (idx >= 0 && voxels[idx].material != 0u) {
            Material m = getVoxelMaterial(voxels[idx].material);




            // ======================= OPACITY HANDLING ==================================
            float opacity = m.opacity; // absorption coefficient
            vec3 col = m.color;

            // Fast branch when reaching opaque block
            if (opacity >= 0.99) {
                accumulatedColor += transparency * col;
                transparency = 0.0;
                steps = i;
                impactPosition = pos;
                return true;
            }


            float travel = t - last_t;
            float absorb = exp(-opacity * travel);

            // classic alpha blend => DOES NOT WORK,  DO NOT USE
            // accumulatedColor += transparency * col * opacity;
            // transparency *= (1.0 - opacity);

            // Opacity exponential remap => walmart Beer-Lambert
            float localOpacity = 1.0 - pow(1.0 - opacity, travel);
            accumulatedColor += transparency * col * localOpacity;
            transparency *= (1.0 - localOpacity);

            // Beer-Lambert physically accurate method (costly)
            // accumulatedColor += transparency * col * (1.0 - absorb);
            // transparency *= absorb;

            if (transparency < 0.01) {
                steps = i;
                impactPosition = pos;
                return true;
            }
        }
        // ======================= !OPACITY HANDLING ==================================


        if (sideDist.x < sideDist.y && sideDist.x < sideDist.z) {
            pos.x += step.x;
            sideDist.x += deltaDist.x;
        } else if (sideDist.y < sideDist.z) {
            pos.y += step.y;
            sideDist.y += deltaDist.y;
        } else {
            pos.z += step.z;
            sideDist.z += deltaDist.z;
        }

        last_t = t;

        if (t > tFar) {
            steps = i;
            impactPosition = pos;
            return true;    
        }
    }

    return false;
}







// hashing function
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
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
    vec3 impactPosition;
    float transparency;
    uint steps;
    raymarch(ro, rd, color, transparency, steps, impactPosition);

    vec3 skyColor = rd.y < 0.0 ? vec3(135, 121, 100) / 255.0 : vec3(103, 159, 201) / 255.0;

    // add a bit of darkening for variation in the same voxel type
    color -= color * hash( impactPosition.x + impactPosition.x*impactPosition.y + impactPosition.x*impactPosition.y*impactPosition.z )*0.07;
    finalColor = vec4(color + transparency * skyColor, 1.0);



    // This displays the number of steps/max steps
    if (RENDER_DEBUG == 1) {
        finalColor = vec4(float(steps)/MAX_STEPS, float(steps)/MAX_STEPS, float(steps)/MAX_STEPS, 1.0);
    }



    // Flattened 3D to 2D, loop through voxels world data. All chunks
    // uint x = uint(gl_FragCoord.x);
    // uint y = uint(gl_FragCoord.y);
    // uint index = y * uint(resolution.x) + x;
    // // get voxel color
    // finalColor = vec4(getVoxelMaterial(voxels[index].material).color, 1.0);


}


// pretty consisten 50+ FPS on RTX 4060, and 25+ on iGPU
// Not too bad for my use case. I will start using some new methods later. Also...
