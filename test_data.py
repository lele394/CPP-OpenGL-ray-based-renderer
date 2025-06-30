import numpy as np

array = np.zeros((8, 8, 8), dtype=np.uint32)

# Set corners
corners = [
    (0,0,0), (0,0,7), (0,7,0), (0,7,7),
    (7,0,0), (7,0,7), (7,7,0), (7,7,7)
]
for corner in corners:
    array[corner] = 1

# Set center
array[4,4,4] = 2
array[4,4,3] = 3
array[4,3,4] = 4
array[4,3,3] = 5
array[3,4,4] = 6
array[3,4,3] = 7
array[3,3,4] = 8
array[3,3,3] = 9

# Save as raw binary (no header)
array.tofile("data.bin")

# Basically an 8x8x8 chunk with voxels on the side and one in the center