# Voxel raymarch CPP

### No, this is not an instruction manual
> Just run the python script in `/data/` to generate sample chunks
> Then ruon`./compexec.sh` and you should be good

Deps are unknown tbh





## Battleplan


#### Next steps :

Load generated chunks back to CPU side (maybe do on a per chunk basis, or rank up to 64 maybe)
Dummy OcTree generation function that returns chunk starting offset and size
Dummy free list of occupied space inside the SSBO on CPU (use idk, blocks of 64bytes )
List of starting offset for each chunks synchronized between CPU/GPU
Extract traversal algorithm and make it use the starting offset list
Check if it still works

If it do, implement octree
check if it works

If it do, try to add some lighting stuff, emissive voxels, reflections etc

Refine terrain generation

Add custom structures (add trees?)

Add caves or something with noise

Add some materials






- Figure out chunk ordering (easy?) [DONE LOL]
- Add transparency [DONE ?]
- Add a material loader 
- Add reflections (?) 
- Add material texture(specular map and all)/skybox (texture loading)