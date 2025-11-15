#rn density field is calculated on the cpu using generateLandDensityField(), we should move it to GPU using this compute shader for surface
# and csg based things, and also it generates 2.5D surface rn, it should generate full 3d slab

#maybe find a glsl version/port of noise library (rn we use fastnoiselite)