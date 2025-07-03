import numpy as np
from noise import pnoise2
from utils import convert_and_save_chunks

def generate_terrain(width=800, height=300, depth=800, ocean_level=150):
    world = np.zeros((width, height, depth), dtype=np.uint32)

    scale = 100.0    # bigger = smoother, smaller = rougher
    octaves = 4
    persistence = 0.5
    lacunarity = 2.0

    # Generate heightmap using fractal Perlin noise
    heightmap = np.zeros((width, depth))
    for x in range(width):
        for z in range(depth):
            nx = x / scale
            nz = z / scale
            elevation = pnoise2(nx, nz, 
                                octaves=octaves, 
                                persistence=persistence, 
                                lacunarity=lacunarity, 
                                repeatx=1024, repeaty=1024, base=42)
            # pnoise2 returns roughly -1..1
            heightmap[x, z] = elevation

    # Normalize to terrain heights
    min_h, max_h = np.min(heightmap), np.max(heightmap)
    heightmap = (heightmap - min_h) / (max_h - min_h) * 40 + (ocean_level - 10)

    # Build the terrain blocks
    for x in range(width):
        for z in range(depth):
            terrain_height = int(heightmap[x, z])
            terrain_height = np.clip(terrain_height, 0, height - 1)

            for y in range(height):
                if y < terrain_height - 5:
                    world[x, y, z] = 1  # stone
                if y < terrain_height - 1:
                    world[x, y, z] = 2  # dirt
                elif y < terrain_height:
                    world[x, y, z] = 3  # grass
                elif y < ocean_level:
                    world[x, y, z] = 4  # water

    return world


if __name__ == "__main__":
    terrain = generate_terrain(512, 64, 512, ocean_level=32)
    convert_and_save_chunks(terrain, 32)
