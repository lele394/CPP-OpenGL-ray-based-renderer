#version 430 core

out vec4 finalColor;

uniform vec2 resolution;
uniform vec3 camPos;
uniform vec3 camRot;
uniform float FOV;

struct Voxel {
    uint material;
};

layout(std430, binding = 0) buffer VoxelData {
    Voxel voxels[];
};

const ivec3 CHUNK_SIZE = ivec3(8, 8, 8);
const float MAX_DIST = 64.0;

vec3 getVoxelColor(uint materialId) {
    if (materialId == 1u) return vec3(1.0, 1.0, 0.0);
    return vec3(0.2, 0.2, 0.2);
}

int worldToIndex(ivec3 pos) {
    if (any(lessThan(pos, ivec3(0))) || any(greaterThanEqual(pos, CHUNK_SIZE))) {
        return -1;
    }
    return pos.z * CHUNK_SIZE.y * CHUNK_SIZE.x + pos.y * CHUNK_SIZE.x + pos.x;
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

bool raymarch(vec3 ro, vec3 rd, out vec3 hitColor) {
    vec3 pos = floor(ro);
    vec3 deltaDist = abs(1.0 / rd);
    vec3 step = sign(rd);
    
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


    for (int i = 0; i < 256; ++i) {
        ivec3 ipos = ivec3(pos);
        int idx = worldToIndex(ipos);
        if (idx >= 0 && voxels[idx].material != 0u) {
            hitColor = getVoxelColor(voxels[idx].material);
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

        if (length(pos - ro) > MAX_DIST)
            break;
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
    if (raymarch(ro, rd, color)) {
        finalColor = vec4(color, 1.0);
    } else {
        color = rd.y < 0.0 ? vec3(135, 121, 100) / 255.0 : vec3(103, 159, 201) / 255.0;
        finalColor = vec4(color, 1.0);
    }
}
