# Voxel raymarch CPP

### No, this is not an instruction manual
> Just run the python script in `/data/` to generate sample chunks
> Then ruon`./compexec.sh` and you should be good

Deps are unknown tbh



### Mixed raw/octree data storing

So the idea is to combine octrees and raw data for fast modification by editing the raw data and simply rebuilding the octree.

Octree only stores an offset/pointer to the voxel inside the raw data

in memory : data_1>octree_1>data_2>octree_2>.....



for allocation : 
Compute size of the raw data => voxel size * chunk size **3
Compute size of the worst case scenario for the octree
=> gives out the offset of the starting position of the octree (obviously raw data is 1)

allocate that size as the chunk reserved space





## Battleplan




- Figure out chunk ordering (easy?) [DONE LOL]
- Add a material loader 
- Add transparency
- Add reflections (?)
- Add material texture(specular map and all)/skybox (texture loading)