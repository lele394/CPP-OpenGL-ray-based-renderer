#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <fstream>
#include <iostream>
#include <sstream>

const int WIDTH = 1280, HEIGHT = 720;

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

float cam_speed = 5.0f;
float mouse_sensitivity = 0.003f;

int main() {
    glfwInit();
    GLFWwindow* win = glfwCreateWindow(WIDTH, HEIGHT, "ShaderDemo", NULL, NULL);
    glfwMakeContextCurrent(win);
    gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);

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

    glm::vec3 camPos(0, 1.0f, 3.0f);
    glm::vec2 camRot(0, 0);
    double lastTime = glfwGetTime();

    // Mouse stuff
    double lastX = WIDTH / 2.0;
    double lastY = HEIGHT / 2.0;
    bool firstMouse = true;


    while (!glfwWindowShouldClose(win)) {

        glfwPollEvents();


        double curTime = glfwGetTime();
        float dt = curTime - lastTime;
        lastTime = curTime;



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
        
        std::cout << "Pitch (X): " << camRot.x << ", Yaw (Y): " << camRot.y << std::endl;
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
        if (glfwGetKey(win, GLFW_KEY_W) == GLFW_PRESS) move += glm::vec3 (forward[0], 0, forward[2]);
        if (glfwGetKey(win, GLFW_KEY_S) == GLFW_PRESS) move -= glm::vec3 (forward[0], 0, forward[2]);
        if (glfwGetKey(win, GLFW_KEY_A) == GLFW_PRESS) move -= glm::vec3 (right[0], 0, right[2]);
        if (glfwGetKey(win, GLFW_KEY_D) == GLFW_PRESS) move += glm::vec3 (right[0], 0, right[2]);
        if (glfwGetKey(win, GLFW_KEY_E) == GLFW_PRESS) move += glm::vec3 (0, 1, 0);
        if (glfwGetKey(win, GLFW_KEY_Q) == GLFW_PRESS) move -= glm::vec3 (0, 1, 0);
        if (glm::length(move) > 0) camPos += glm::normalize(move) * cam_speed * dt;

        // ===================== ! I N P U T ===============================


        // Rendering
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(shader);
        glUniform2f(locRes, WIDTH, HEIGHT);
        glUniform3f(locCamPos, camPos.x, camPos.y, camPos.z);
        glUniform3f(locCamRot, camRot.x, camRot.y, 0.0);
        glUniform1f(locFOV, 60.0f);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(win);
    }

    glfwDestroyWindow(win);
    glfwTerminate();
}
