#include "glad/gl.h"
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
#include <random>

// Screen size
const int WIDTH = 1280, HEIGHT = 720;
// const int WIDTH = 1024, HEIGHT = 1080; // Cool dimension to use to display the world

const int CHUNK_SIZE = 32;
const glm::ivec3 WORLD_DIM = glm::ivec3(16, 2, 16);  // Wx, Wy, Wz

const size_t CHUNK_VOXELS = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE;
const size_t TOTAL_CHUNKS = WORLD_DIM.x * WORLD_DIM.y * WORLD_DIM.z;
const size_t TOTAL_VOXELS = TOTAL_CHUNKS * CHUNK_VOXELS;



// Setup random number generator
// I just randomize the data I load lol <= I don't do that anymore
// std::random_device rd;
// std::mt19937 gen(rd());
// std::uniform_int_distribution<> distrib(1, 35); // generates numbers 1..35




std::string load_file(const char* path) {
    std::ifstream file(path);
    std::stringstream ss;
    ss << file.rdbuf();
    return ss.str();
}

GLuint compile_shader(const char* src, GLenum type) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &src, NULL);
    glCompileShader(shader);
    char log[512];
    glGetShaderInfoLog(shader, 512, NULL, log);
    std::cerr << log << std::endl;
    return shader;
}


GLuint compileComputeShader(const std::string& filename) {
    // === Read shader source from file ===
    std::ifstream in(filename);
    if (!in.is_open()) {
        throw std::runtime_error("Failed to open compute shader file: " + filename);
    }
    std::stringstream buffer;
    buffer << in.rdbuf();
    std::string sourceStr = buffer.str();
    const char* source = sourceStr.c_str();

    // === Create and compile shader ===
    GLuint shader = glCreateShader(GL_COMPUTE_SHADER);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    // === Check compile errors ===
    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        GLint logLength;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
        std::vector<char> infoLog(logLength);
        glGetShaderInfoLog(shader, logLength, nullptr, infoLog.data());
        std::cerr << "Compute Shader compilation failed:\n" << infoLog.data() << std::endl;
        throw std::runtime_error("Compute Shader compilation failed.");
    }

    // === Create program and link ===
    GLuint program = glCreateProgram();
    glAttachShader(program, shader);
    glLinkProgram(program);

    // === Check linking errors ===
    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        GLint logLength;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
        std::vector<char> infoLog(logLength);
        glGetProgramInfoLog(program, logLength, nullptr, infoLog.data());
        std::cerr << "Compute Shader linking failed:\n" << infoLog.data() << std::endl;
        throw std::runtime_error("Compute Shader linking failed.");
    }

    // === Clean up ===
    glDeleteShader(shader);

    return program;
}



GLuint create_program(const char* vsrc, const char* fsrc) {
    GLuint vert = compile_shader(vsrc, GL_VERTEX_SHADER);
    GLuint frag = compile_shader(fsrc, GL_FRAGMENT_SHADER);
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vert);
    glAttachShader(prog, frag);
    glLinkProgram(prog);
    glDeleteShader(vert);
    glDeleteShader(frag);
    return prog;
}

float quad[] = {
    -1, -1, 1, -1, 1, 1,
    -1, -1, 1, 1, -1, 1,
};

float cam_speed = 8.0f;
float mouse_sensitivity = 0.003f;

// ================== Voxel struct and values ============
struct Voxel {
    uint32_t material;
};


// For loading files, need to redo tha part with OCREE support
// void loadChunkToMasterSSBO(GLuint ssbo, std::string filepath, int chunkIndex) {
//     std::ifstream in(filepath, std::ios::binary);
//     if (!in) throw std::runtime_error("Failed to open chunk file : " + filepath);

//     std::vector<uint32_t> data(CHUNK_VOXELS);
//     in.read(reinterpret_cast<char*>(data.data()), data.size() * sizeof(uint32_t));
//     in.close();

//     size_t offset = chunkIndex * CHUNK_VOXELS * sizeof(uint32_t);
//     glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
//     glBufferSubData(GL_SHADER_STORAGE_BUFFER, offset, data.size() * sizeof(uint32_t), data.data());
// }

// ================== ! Voxel struct and values ============




// FPS counter : 
const int FPS_SAMPLES = 100;
float frameTimes[FPS_SAMPLES] = {0.0f}; // initialize with zeros
int frameIndex = 0;
bool filled = false;


int main() {
    glfwInit();
    GLFWwindow* win = glfwCreateWindow(WIDTH, HEIGHT, "ShaderDemo", NULL, NULL);
    glfwMakeContextCurrent(win);
    if (!gladLoadGL(glfwGetProcAddress)) {
        std::cerr << "Failed to initialize GLAD\n";
        return -1;
    }
    glfwSetInputMode(win, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    GLuint vao, vbo;
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);
    glGenBuffers(1, &vbo); glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    std::string vsrc = load_file("shaders/vertex.glsl");
    std::string fsrc = load_file("shaders/shader.glsl");
    GLuint shader = create_program(vsrc.c_str(), fsrc.c_str());

    GLint locRes = glGetUniformLocation(shader, "resolution");
    GLint locCamPos = glGetUniformLocation(shader, "camPos");
    GLint locCamRot = glGetUniformLocation(shader, "camRot");
    GLint locFOV = glGetUniformLocation(shader, "FOV");

    // Chunk world stuff == Initialization
    GLint chunkSizeLoc = glGetUniformLocation(shader, "chunkSize");
    GLint worldDimLoc = glGetUniformLocation(shader, "worldDim");

    // Visual debug cycler
    int RENDER_DEBUG = 0;
    GLint RENDER_DEBUGLoc = glGetUniformLocation(shader, "RENDER_DEBUG");
    glUniform1i(RENDER_DEBUGLoc, RENDER_DEBUG);

    glUseProgram(shader); // needed to start assigning values
    glUniform1i(chunkSizeLoc, CHUNK_SIZE);
    glUniform3i(worldDimLoc, WORLD_DIM.x, WORLD_DIM.y, WORLD_DIM.z);







    glm::vec3 camPos(-58.6984, 123.135, -19.7525);
    glm::vec2 camRot(0.561, 2.151);
    double lastTime = glfwGetTime();

    // Mouse stuff
    double lastX = WIDTH / 2.0;
    double lastY = HEIGHT / 2.0;
    bool firstMouse = true;








    // ======= voxel SSBO =========
    GLuint voxelSSBO, octreeSSBO;

    // ===== Allocate voxel buffer =====
    glGenBuffers(1, &voxelSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, voxelSSBO);
    
    size_t per_chunk_raw_size = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * sizeof(uint32_t);
    size_t total_voxel_size = TOTAL_CHUNKS * per_chunk_raw_size;
    
    glBufferData(GL_SHADER_STORAGE_BUFFER, total_voxel_size, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, voxelSSBO);
    
    
    // ===== Allocate octree buffer =====
    glGenBuffers(1, &octreeSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, octreeSSBO);
    
    int levels = (int)std::log2(CHUNK_SIZE);
    size_t octree_nodes_per_chunk = (std::pow(8, levels + 1) - 1) / 7;
    size_t per_chunk_octree_size = octree_nodes_per_chunk * sizeof(uint32_t);    
    size_t total_octree_size = TOTAL_CHUNKS * per_chunk_octree_size;

    glBufferData(GL_SHADER_STORAGE_BUFFER, total_octree_size, nullptr, GL_DYNAMIC_DRAW);
    
    bool LoadFromFile = false;
    // ===== Voxel creation =====
    if (LoadFromFile) {
        throw std::invalid_argument("Loading from file not implemented since sw");
        // // load all chunks to master SSBO ===== currently data.bin as debug
        // for (int z = 0; z < WORLD_DIM.z; ++z)
        // for (int y = 0; y < WORLD_DIM.y; ++y)
        // for (int x = 0; x < WORLD_DIM.x; ++x) {
        //     int chunkIndex = z * WORLD_DIM.y * WORLD_DIM.x + y * WORLD_DIM.x + x;
        //     std::string filename = "../data/chunk-" + std::to_string(x) + "-" + std::to_string(y) + "-" + std::to_string(z) + ".bin";
        //     loadChunkToMasterSSBO(masterSSBO, filename, chunkIndex);
        //     // std::cout << " Loaded \t"<<x<<",\t"<<y<<",\t"<<z << "\t"<<filename<< std::endl;
    } else {
        GLuint voxelComputeShader = compileComputeShader("shaders/voxel.glsl");
        glUseProgram(voxelComputeShader);
        glUniform3i(glGetUniformLocation(voxelComputeShader, "worldDim"), WORLD_DIM.x, WORLD_DIM.y, WORLD_DIM.z);
        glUniform1i(glGetUniformLocation(voxelComputeShader, "chunkSize"), CHUNK_SIZE);
    
        glDispatchCompute(WORLD_DIM.x, WORLD_DIM.y, WORLD_DIM.z);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    
    
        GLuint octreeComputeShader = compileComputeShader("shaders/build_octree.glsl");
        glUseProgram(octreeComputeShader);
        glUniform3i(glGetUniformLocation(octreeComputeShader, "worldDim"), WORLD_DIM.x, WORLD_DIM.y, WORLD_DIM.z);
        glUniform1i(glGetUniformLocation(octreeComputeShader, "chunkSize"), CHUNK_SIZE);
    
        glDispatchCompute(WORLD_DIM.x, WORLD_DIM.y, WORLD_DIM.z);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    }
    
    std::cout << "Voxel buffer size:   " << total_voxel_size << " bytes" << std::endl;
    std::cout << "Octree buffer size:  " << total_octree_size << " bytes" << std::endl;
    

    // =========== ! voxel SSBO ============







    while (!glfwWindowShouldClose(win)) {

        glfwPollEvents();

        // std::cout << "Position : " << camPos.x << "  " << camPos.y << "  " << camPos.z << std::endl;


        double curTime = glfwGetTime();
        float dt = curTime - lastTime;
        lastTime = curTime;


        // FPS counter
        frameTimes[frameIndex] = dt;
        frameIndex = (frameIndex + 1) % FPS_SAMPLES;
        if (frameIndex == 0) filled = true;
        float sum = 0.0f;
        int count = filled ? FPS_SAMPLES : frameIndex;
        
        for (int i = 0; i < count; ++i) {
            sum += frameTimes[i];
        }
        
        float avgDt = sum / count;
        float avgFps = 1.0f / avgDt;
        
        std::cout << "Avg FPS (last " << count << "): " << avgFps << "\r" ;
        std::cout.flush();
        // !FPS counter

        // ===================== I N P U T ===============================
        
        // ==== MOUSE =====
        double xpos, ypos;
        glfwGetCursorPos(win, &xpos, &ypos);

        if (firstMouse) // First frame jump fix
        {
            lastX = xpos;
            lastY = ypos;
            firstMouse = false;
        }
    
        // Calculate the mouse's movement since the last frame
        float xoffset = xpos - lastX;
        float yoffset = ypos - lastY; // Reversed since y-coordinates go from top to bottom
    
        // Update the last position for the next frame
        lastX = xpos;
        lastY = ypos;
    
        camRot.y += xoffset * mouse_sensitivity; // Yaw
        camRot.x += yoffset * mouse_sensitivity; // Pitch

        camRot.y = fmod(camRot.y, glm::two_pi<float>());
        if (camRot.y < 0.0f) {
            camRot.y += glm::two_pi<float>();
        }
    
        // Your pitch clamping is still correct and necessary
        camRot.x = glm::clamp(camRot.x, -glm::half_pi<float>() + 0.01f, glm::half_pi<float>() - 0.01f);
        // glfwSetCursorPos(win, WIDTH / 2, HEIGHT / 2);
        
        // std::cout << "Pitch (X): " << camRot.x << ", Yaw (Y): " << camRot.y << std::endl;
        // ============== !MOUSE

        glm::vec3 right(
            cos(camRot.y) * cos(camRot.x),
            sin(camRot.x),
            sin(camRot.y) * cos(camRot.x)  // ← negate if needed
        );
        glm::vec3 forward(
            sin(camRot.y), 0, -cos(camRot.y) // original
        );
        // glm::vec3 up = glm::cross(right, forward);

        glm::vec3 move(0.0f);
        float speed_multiplier = 1.0;
        if (glfwGetKey(win, GLFW_KEY_W) == GLFW_PRESS) move += glm::vec3 (forward[0], 0, forward[2]);
        if (glfwGetKey(win, GLFW_KEY_S) == GLFW_PRESS) move -= glm::vec3 (forward[0], 0, forward[2]);
        if (glfwGetKey(win, GLFW_KEY_A) == GLFW_PRESS) move -= glm::vec3 (right[0], 0, right[2]);
        if (glfwGetKey(win, GLFW_KEY_D) == GLFW_PRESS) move += glm::vec3 (right[0], 0, right[2]);
        if (glfwGetKey(win, GLFW_KEY_E) == GLFW_PRESS) move += glm::vec3 (0, 1, 0);
        if (glfwGetKey(win, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS) speed_multiplier = 7.0f;
        if (glfwGetKey(win, GLFW_KEY_Q) == GLFW_PRESS) move -= glm::vec3 (0, 1, 0);
        if (glm::length(move) > 0) camPos += glm::normalize(move) * cam_speed * dt * speed_multiplier;

        if (glfwGetKey(win, GLFW_KEY_UP) == GLFW_PRESS){ 
            RENDER_DEBUG = 0;
        }
        if (glfwGetKey(win, GLFW_KEY_DOWN) == GLFW_PRESS){ 
            RENDER_DEBUG = 1;
        }

        if (glfwGetKey(win, GLFW_KEY_ESCAPE) == GLFW_PRESS) return 0; // quit


        // std::cout <<  "Position : " << camPos.x << ", " << camPos.y << ", " << camPos.z << std::endl;
        // std::cout.flush();

        // ===================== ! I N P U T ===============================


        // Rendering
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(shader);
        glUniform2f(locRes, WIDTH, HEIGHT);
        glUniform3f(locCamPos, camPos.x, camPos.y, camPos.z);
        glUniform3f(locCamRot, camRot.x, camRot.y, 0.0);
        glUniform1i(RENDER_DEBUGLoc, RENDER_DEBUG);
        glUniform1f(locFOV, 60.0f);
        glDrawArrays(GL_TRIANGLES, 0, 6);





        glfwSwapBuffers(win);
    }

    glfwDestroyWindow(win);
    glfwTerminate();
}
