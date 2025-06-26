# Previous build cleanup
rm -rf build
rm -rf shaders

# reqs directories
mkdir build
mkdir build/shaders

# Copy shaders
cp ./shader.glsl ./build/shaders/shader.glsl
cp ./vertex.glsl ./build/shaders/vertex.glsl

cd build
cmake ..
make
./ShaderDemo