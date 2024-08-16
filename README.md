# HardWare Acceleration of RayTracing with MSL

Based on the "Ray Tracing in One Weekend (Peter Shirley, Trevor David Black, Steve Hollasch)".
HardWare Acceleration code using Apple's Metal API, written in MSL(Metal Shader Language)

## How to Compile and Run

1. Go to directory : /src (via terminal)
2. Compile the main.cpp file (c++11 compiler Recommended)
3. run the execution file with the output file name : ex. ./main > output.ppm

example : g++ -std=c++11 -I. main.cpp -o main && ./main > output.ppm

then the output will be saved as a ppm file.
