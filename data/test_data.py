# import numpy as np

# array = np.zeros((8, 8, 8), dtype=np.uint32)

# # Set corners
# corners = [
#     (0,0,0), (0,0,7), (0,7,0), (0,7,7),
#     (7,0,0), (7,0,7), (7,7,0), (7,7,7)
# ]
# for corner in corners:
#     array[corner] = 1

# # Set center
# array[4,4,4] = 2
# array[4,4,3] = 3
# array[4,3,4] = 4
# array[4,3,3] = 5
# array[3,4,4] = 6
# array[3,4,3] = 7
# array[3,3,4] = 8
# array[3,3,3] = 9

# # Save as raw binary (no header)
# array.tofile("data.bin")

# Basically an 8x8x8 chunk with voxels on the side and one in the center




import numpy as np


def generate_chunk(size=8, sphere_radius=2.5, material=2):
    array = np.zeros((size, size, size), dtype=np.uint32)

    # Set edges of the cube to material 1
    for x in range(size):
        for y in range(size):
            for z in range(size):
                is_edge = (
                    (x == 0 or x == size-1) +
                    (y == 0 or y == size-1) +
                    (z == 0 or z == size-1)
                )
                if is_edge >= 2:
                    array[x, y, z] = 1

    # Set sphere in center with material 2
    center = np.array([size/2, size/2, size/2])
    for x in range(size):
        for y in range(size):
            for z in range(size):
                dist = np.linalg.norm(np.array([x+0.5, y+0.5, z+0.5]) - center)
                if dist < sphere_radius:
                    array[x, y, z] = material

    return array


def generate_chunk2(size=8, sphere_radius=2.5, material=2):
    array = np.zeros((size, size, size), dtype=np.uint32)

    # Set corners to material 1
    corners = [
        (0,0,0), (0,0,size-1), (0,size-1,0), (0,size-1,size-1),
        (size-1,0,0), (size-1,0,size-1), (size-1,size-1,0), (size-1,size-1,size-1)
    ]
    for corner in corners:
        array[corner] = 1

    # Set sphere in center with material 2
    center = np.array([size/2, size/2, size/2])
    for x in range(size):
        for y in range(size):
            for z in range(size):
                dist = np.linalg.norm(np.array([x+0.5,y+0.5,z+0.5]) - center)
                if dist < sphere_radius:
                    array[x,y,z] = material

    return array

# Example usage
size = 32          # change chunk size here
sphere_radius = 3  # change sphere radius here

for i in range(35):
    chunk = generate_chunk(size=size, sphere_radius=sphere_radius, material=i+1)
    chunk.tofile(f"data-{i+1}.bin")


# 32 by 32 by 32 chunks with a sphere in the middle and voxels on the corners
