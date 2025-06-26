
#version 330 core

out vec4 finalColor;

uniform vec2 resolution;
uniform vec3 camPos;
uniform vec3 camRot;
uniform float FOV;

// Rotate a vector by Euler angles
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















// Scene SDF: returns min distance and object ID
// vec2 sceneSDF(vec3 p) {
//     float d1 = sdfSphere(p, vec3(0.0, 0.0, 0.0), 1.0);
//     float d2 = sdfSphere(p, vec3(2.0, 1.0, 0.0), 1.5);
//     float d3 = sdfSphere(p, vec3(-2.0, 1.0, 0.0), 0.5);

//     float minDist = d1;
//     float id = 1.0;

//     if (d2 < minDist) {
//         minDist = d2;
//         id = 2.0;
//     }

//     if (d3 < minDist) {
//         minDist = d3;
//         id = 3.0;
//     }

//     return vec2(minDist, id);
// }










// ============================= COOL SDFs ===============================


// Untested
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

// Untested
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}


// Untested
float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Untested
float sdCylinder(vec3 p, float r) { // infinite length
    return length(p.xz) - r;
}

// Untested
float sdCappedCylinder(vec3 p, float h, float r) { // has caps
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Untested
float sdCone(vec3 p, float h, float r) {
    float q = length(p.xz);
    return max(dot(vec2(r, h), vec2(q, -p.y)) / sqrt(r*r + h*h), -p.y);
}

// Untested
float sdPlane(vec3 p, vec3 n, float h) {
    return dot(p, normalize(n)) + h;
}

// Untested
float sdRoundedBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) - r;
}



// =================== FRACTALS =======================

float menger(vec3 p) {
    float scale = 0.20;
    float d = sdBox(p, vec3(1.0));
    for (int i = 0; i < 4; i++) {
        p = mod(p * 3.0, 2.0) - 1.0;  // Fold into repeated unit cell
        vec3 q = abs(p) - 0.5;       // Subtract center cube
        float hole = sdBox(q, vec3(0.2));
        d = max(d, -hole / scale);   // Subtract hole
        scale *= 3.0;
    }
    return d;
}




float sierpinski(vec3 p) {
    float scale = 1.0;
    for (int i = 0; i < 6; i++) {
        if (p.x + p.y < 0.0) p.xy = -p.yx;
        if (p.x + p.z < 0.0) p.xz = -p.zx;
        if (p.y + p.z < 0.0) p.yz = -p.zy;
        p = p * 2.0 - 1.0;
        scale *= 2.0;
    }
    return length(p) / scale - 0.02;
}



vec3 fold(vec3 p) {
    p = abs(p);
    if (p.x < p.y) p.xy = p.yx;
    if (p.x < p.z) p.xz = p.zx;
    if (p.y < p.z) p.yz = p.zy;
    return p;
}
float kaleido(vec3 p) {
    for (int i = 0; i < 5; ++i) {
        p = fold(p);
        p = p * 2.0 - vec3(1.0);
    }
    return length(p) - 0.5;
}



float mandelbulb(vec3 p) {
    vec3 z = p;
    float dr = 1.0;
    float r = 0.0;
    const int ITER = 8;
    const float power = 8.0;
    for (int i = 0; i < ITER; ++i) {
        r = length(z);
        if (r > 4.0) break;

        // Convert to polar coordinates
        float theta = acos(z.z / r);
        float phi = atan(z.y, z.x);
        dr =  pow(r, power - 1.0) * power * dr + 1.0;

        // Scale and rotate
        float zr = pow(r, power);
        theta *= power;
        phi *= power;

        // Convert back to cartesian coordinates
        z = zr * vec3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta)) + p;
    }
    return 0.5 * log(r) * r / dr;
}




// Doesn't looks like it works tbh
float quaternionJulia(vec3 p) {
    vec4 z = vec4(p, 0.3);        // Embed 3D pos into 4D quaternion space
    vec4 c = vec4(0.2, 0.35, 0.1, -0.4); // Julia constant (can animate this)

    float dr = 1.0;
    float r = 0.0;

    for (int i = 0; i < 20; i++) {
        r = dot(z, z);
        if (r > 4.0) break;

        // Quaternion derivative update
        dr = 2.0 * sqrt(r) * dr;

        // z = z^2 + c (Quaternion multiplication)
        vec4 z_new;
        z_new.x = z.x*z.x - z.y*z.y - z.z*z.z - z.w*z.w;
        z_new.y = 2.0*z.x*z.y;
        z_new.z = 2.0*z.x*z.z;
        z_new.w = 2.0*z.x*z.w;
        z = z_new + c;
    }

    return 0.5 * log(r) * sqrt(r) / dr;
}

// ======================= VOXEL STUFF ====================
const int gridSize = 3;
const float voxelSize = 1.0;

// Flat array: 3x3x3 = 27 elements, row-major order (z, then y, then x)
// 1 = filled, 0 = empty
// Filled corners only
int voxelData[27] = int[27](
    1, 0, 1,   // z = 0, y = 0, x = 0..2
    0, 0, 0,
    1, 0, 1,

    0, 0, 0,   // z = 1
    0, 0, 0,
    0, 0, 0,

    1, 0, 1,   // z = 2
    0, 0, 0,
    1, 0, 1
);

// Utility: get voxel value at (x, y, z)
int getVoxel(int x, int y, int z) {
    if (x < 0 || x >= gridSize || y < 0 || y >= gridSize || z < 0 || z >= gridSize) return 0;
    return voxelData[x + y * gridSize + z * gridSize * gridSize];
}


float voxelSDF(vec3 p) {
    vec3 p_grid = p / voxelSize;
    ivec3 base = ivec3(floor(p_grid));
    
    float minDist = 1e6;

    for (int dz = -1; dz <= 1; dz++) {
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                ivec3 idx = base + ivec3(dx, dy, dz);
                if (getVoxel(idx.x, idx.y, idx.z) == 0) continue;

                vec3 center = (vec3(idx) + 0.5) * voxelSize;
                float d = sdBox(p - center, vec3(0.5 * voxelSize));
                minDist = min(minDist, d);
            }
        }
    }

    return minDist;
}


// ======================== SCENE =====================

vec2 sceneSDF(vec3 p) {
    // Sphere at center
    // float sph = sdSphere(p - vec3(0.0, 0.5, 0.0), 0.5);
    
    // // Box base/platform
    // float box = sdBox(p - vec3(0.0, -1.25, 0.0), vec3(2.0, 0.25, 2.0));
    
    // // Torus above sphere
    // float torus = sdTorus(p - vec3(0.0, 1.2, 0.0), vec2(0.6, 0.15));
    
    // // Three rounded boxes arranged like pillars
    // float rbox1 = sdRoundedBox(p - vec3(-1.2, -0.25, 0.0), vec3(0.2, 1.0, 0.2), 0.1);
    // float rbox2 = sdRoundedBox(p - vec3(1.2, -0.25, 0.0), vec3(0.2, 1.0, 0.2), 0.1);
    // float rbox3 = sdRoundedBox(p - vec3(0.0, -0.25, -1.2), vec3(0.2, 1.0, 0.2), 0.1);

    // // Capped cylinder in the back
    // float capCyl = sdCappedCylinder(p - vec3(0.0, -0.25, 1.5), 1.0, 0.2);

    // voxel
    // float voxel = voxelSDF(p - vec3(0.0, 2.0, 0.0));

    // Combine all with min() and encode ID
    // float d = sph;
    // float id = 1.0;

    // if (box < d) { d = box; id = 2.0; }
    // if (torus < d) { d = torus; id = 3.0; }
    // if (rbox1 < d) { d = rbox1; id = 4.0; }
    // if (rbox2 < d) { d = rbox2; id = 4.0; }
    // if (rbox3 < d) { d = rbox3; id = 4.0; }
    // if (capCyl < d) { d = capCyl; id = 5.0; }
    // if (voxel < d) { d = voxel; id = 5.0; }

    // float d = mandelbulb(p*0.2);
    float id = 1.0;

    float d = sdSphere(p - vec3(0.0, 0.0, 0.0), 0.5);

    return vec2(d, id);
}



// Estimate surface normal via gradient
vec3 estimateNormal(vec3 p) {
    float eps = 0.001;
    vec2 e = vec2(1.0, 0.0) * eps;

    return normalize(vec3(
        sceneSDF(p + vec3(e.x, 0.0, 0.0)).x - sceneSDF(p + vec3(e.y, 0.0, 0.0)).x,
        sceneSDF(p + vec3(0.0, e.x, 0.0)).x - sceneSDF(p + vec3(0.0, e.y, 0.0)).x,
        sceneSDF(p + vec3(0.0, 0.0, e.x)).x - sceneSDF(p + vec3(0.0, 0.0, e.y)).x
    ));
}




float raymarch(vec3 ro, vec3 rd, out vec3 hitPos, out float objID) {

    // Raymarching function to find the intersection point of a ray with the scene
    // Inputs:
    //   ro - ray origin
    //   rd - ray direction (should be normalized)
    // Outputs:
    //   hitPos - position where the ray hits the surface
    //   objID - ID of the object hit (if any), -1.0 if no hit
    // Returns:
    //   distance along the ray to the intersection point, or -1.0 if no hit

    float t = 0.0;       // total distance marched along the ray
    objID = -1.0;        // initialize object ID to "no hit"

    // Maximum of 100 steps to prevent infinite loop
    for (int i = 0; i < 1000; ++i) {
        hitPos = ro + t * rd;     // compute current position along the ray
        vec2 d = sceneSDF(hitPos); // d.x = distance to nearest surface, d.y = object ID

        if (d.x < 1e-4) {         // close enough to consider a hit
            objID = d.y;          // store object ID
            return t;             // return distance to hit
        }

        t += d.x;                 // march forward by the distance to the closest surface

        if (t > 10000.0) break;   // prevent going too far, assume no hit
    }

    return -1.0; // no hit found within limits
}



float softShadow(vec3 ro, vec3 rd) {
    float res = 1.0;
    float t = 0.01;
    for (int i = 0; i < 64; ++i) {
        vec3 p = ro + rd * t;
        float h = sceneSDF(p).x;
        if (h < 0.001) return 0.0; // fully shadowed
        res = min(res, 10.0 * h / t); // softness factor
        t += h;
        if (t > 20.0) break;
    }
    return clamp(res, 0.0, 1.0);
}




const vec3 colorTable[6] = vec3[](
    vec3(1.0),             // fallback/default color (index 0)
    vec3(1.0, 0.6, 0.6),   // id 1 - Sphere
    vec3(0.2, 0.2, 0.2),   // id 2 - Platform
    vec3(1.0, 0.8, 0.2),   // id 3 - Torus
    vec3(0.5, 0.7, 1.0),   // id 4 - Pillars
    vec3(0.8, 0.3, 0.3)    // id 5 - Back cylinder
);


void main() {
    vec2 uv = (gl_FragCoord.xy / resolution) * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;

    float fovScale = tan(radians(FOV) * 0.5);
    vec3 rd = normalize(vec3(uv.x * fovScale, uv.y * fovScale, -1.0));

    mat3 rot = getRotationMatrix(camRot);
    rd = rot * rd;

    vec3 ro = camPos;
    vec3 hitPos;
    float objID;

    // default color with horizon
    vec3 color;
    if (rd.y < 0.0) {
        color = vec3(135, 121, 100)/255;
    }
    else {
        color = vec3(103, 159, 201)/255;
    }



    float dist = raymarch(ro, rd, hitPos, objID);

    if (dist > 0.0) {
        vec3 normal = estimateNormal(hitPos);
        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));

        // Shadow computation
        float shadow = max(softShadow(hitPos + normal * 0.01, lightDir), 0.2);

        float diffuse = max(dot(normal, lightDir), 0.2) * shadow;
        // float diffuse = 1.0 * shadow;

        // Assign color by object ID
        color = colorTable[int(objID)]; // make sure the number of materials is right
        //                       ^ Necessary to cast

        color *= diffuse;

        // Optional: view surface normals
        color = normal;
    }

    finalColor = vec4(color, 1.0);
}