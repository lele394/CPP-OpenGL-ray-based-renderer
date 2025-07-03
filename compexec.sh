# Previous build cleanup
rm -rf build
rm -rf shaders

# reqs directories
mkdir build
mkdir build/shaders

# Copy shaders
cp ./shader.glsl ./build/shaders/shader.glsl
cp ./vertex.glsl ./build/shaders/vertex.glsl
cp ./voxel.glsl ./build/shaders/voxel.glsl

# copy test voxel data
# python test_data.py
# cp ./data.bin ./build/data.bin

cd build
cmake ..
make
./ShaderDemo