#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <iostream>
#include <fstream>
#include "../include/camera.h"
#include "../include/interval.h"
#include "../include/material.h"
#import <simd/simd.h>

typedef simd::float3 float3;

enum MaterialType {
    Lambertian,
    Metal,
    Dielectric
};

struct My_Material {
    int material_type;
    float3 albedo;
    float fuzz;
    float refraction_index;
};

struct Sphere {
    float3 center;
    float radius;
    My_Material mat;
};

struct hittable_list {
    Sphere spheres[200];
    int sphere_count;
};

struct Camera {
    float3 center;
    float3 pixel00_loc;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float defocus_angle;
    float3 defocus_disk_u;
    float3 defocus_disk_v;
};

void printSphereData(const Sphere* spheres, int count) {
    for (int i = 0; i < count; ++i) {
        std::cout << "Sphere " << i << ": Center("
                  << spheres[i].center.x << ", "
                  << spheres[i].center.y << ", "
                  << spheres[i].center.z << "), Radius: "
                  << spheres[i].radius << ", Material Type: "
                  << spheres[i].mat.material_type << ", Albedo: ("
                  << spheres[i].mat.albedo.x << ", " << spheres[i].mat.albedo.y << ", " << spheres[i].mat.albedo.z << "), fuzz: "
                  << spheres[i].mat.fuzz << ", refraction_index: "
                  << spheres[i].mat.refraction_index << std::endl;
    }
}

void printCameraData(const Camera camera) {
        std::cout << "Center("
                  << camera.center.x << ", "
                  << camera.center.y << ", "
                  << camera.center.z << ")\npixel00_loc: ("
                  << camera.pixel00_loc.x << ", "
                  << camera.pixel00_loc.y << ", "
                  << camera.pixel00_loc.z << ")\npixel_delta_u: ("
                  << camera.pixel_delta_u.x << ", "
                  << camera.pixel_delta_u.y << ", "
                  << camera.pixel_delta_u.z << ")\npixel_delta_v: ("
                  << camera.pixel_delta_v.x << ", "
                  << camera.pixel_delta_v.y << ", "
                  << camera.pixel_delta_v.z << ") " << std::endl;
}


int main() {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            std::cerr << "Metal is not supported on this device" << std::endl;
            return -1;
        }

        id<MTLCommandQueue> commandQueue = [device newCommandQueue];

        NSError* error = nil;
        NSString* shaderPath = [NSString stringWithUTF8String:"src/shaders.metal"];
        NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            std::cerr << "Failed to read shader file: " << error.localizedDescription.UTF8String << std::endl;
            return -1;
        }

        id<MTLLibrary> library = [device newLibraryWithSource:shaderSource options:nil error:&error];
        if (error) {
            std::cerr << "Failed to compile shader: " << error.localizedDescription.UTF8String << std::endl;
            return -1;
        }

        id<MTLFunction> function = [library newFunctionWithName:@"render"];
        id<MTLComputePipelineState> pipelineState = [device newComputePipelineStateWithFunction:function error:&error];
        if (error) {
            std::cerr << "Failed to create pipeline state: " << error.localizedDescription.UTF8String << std::endl;
            return -1;
        }

        camera cam;

        cam.aspect_ratio      = 16.0 / 9.0;
        cam.image_width       = 1200;
        cam.samples_per_pixel = 500;
        cam.max_depth         = 50;

        cam.vfov     = 20;
        cam.lookfrom = point3(13, 2, 3);
        cam.lookat   = point3(0, 0, 0);
        cam.vup      = vec3(0, 1, 0);

        cam.defocus_angle = 0.6;
        cam.focus_dist    = 10.0;

        cam.initialize();
        
        const int image_width = cam.image_width;
        const int image_height = static_cast<int>(image_width / cam.aspect_ratio);
        const int samples_per_pixel = cam.samples_per_pixel;
        const int max_depth = cam.max_depth;
        const int num_pixels = image_width * image_height;
        const int buffer_size = num_pixels * 3 * sizeof(float);

        printf("%d * %d\n", cam.image_width, cam.image_height);

        id<MTLBuffer> pixelBuffer = [device newBufferWithLength:buffer_size options:MTLResourceStorageModeShared];

        Camera metal_cam = { {static_cast<float>(cam.center.x()), static_cast<float>(cam.center.y()), static_cast<float>(cam.center.z())},
                             {static_cast<float>(cam.pixel00_loc.x()), static_cast<float>(cam.pixel00_loc.y()), static_cast<float>(cam.pixel00_loc.z())},
                             {static_cast<float>(cam.pixel_delta_u.x()), static_cast<float>(cam.pixel_delta_u.y()), static_cast<float>(cam.pixel_delta_u.z())},
                             {static_cast<float>(cam.pixel_delta_v.x()), static_cast<float>(cam.pixel_delta_v.y()), static_cast<float>(cam.pixel_delta_v.z())},
                             static_cast<float>(cam.defocus_angle),
                             {static_cast<float>(cam.defocus_disk_u.x()), static_cast<float>(cam.defocus_disk_u.y()), static_cast<float>(cam.defocus_disk_u.z())},
                             {static_cast<float>(cam.defocus_disk_v.x()), static_cast<float>(cam.defocus_disk_v.y()), static_cast<float>(cam.defocus_disk_v.z())} };
        id<MTLBuffer> cameraBuffer = [device newBufferWithBytes:&metal_cam length:sizeof(Camera) options:MTLResourceStorageModeShared];

        // My_Material material_center = { Lambertian, {0.1f, 0.2f, 0.5f}, 0.0f, 0.0f };
        // My_Material material_right  = { Metal, {0.8f, 0.6f, 0.2f}, 0.0f, 0.0f };
        // My_Material material_left   = { Dielectric, {0.0f, 0.0f, 0.0f}, 0.0f, 1.50f };
        // My_Material material_bubble = { Dielectric, {0.0f, 0.0f, 0.0f}, 0.0f, 1.00/1.50f };

        My_Material material_ground = { Lambertian, {0.5f, 0.5f, 0.5f}, 0.0f, 0.0f };
        My_Material material1 = { Dielectric, { 0.0f, 0.0f, 0.0f }, 0.0f, 1.5f };
        My_Material material2 = { Lambertian, { 0.4f, 0.2f, 0.1f }, 0.0f, 0.0f };
        My_Material material3 = { Metal, { 0.7f, 0.6f, 0.5f }, 0.0f, 0.0f };
 
        Sphere sphere[200];

        sphere[0] = { {0.0f, -1000.0f, -1.0f}, 1000.0f, material_ground };
        sphere[1] = { { 0.0f, 1.0f, 0.0f }, 1.0f, material1 };
        sphere[2] = { { -4.0f, 1.0f, 0.0f }, 1.0f, material2 };
        sphere[3] = { { 4.0f, 1.0f, 0.0f }, 1.0f, material3 };

        int index = 4;

        for (int a = -11; a < 11; a++) {
            for (int b = -11; b < 11; b++) {
                double choose_mat = random_double();
                point3 center(a + 0.9 * random_double(), 0.2, b + 0.9 * random_double());
                
                double probability = random_double();

                if ( probability < 0.6 ) continue;

                if ( (center - point3(4, 0.2, 0)).length() > 0.9 ) {
                    My_Material sphere_material;

                    if (choose_mat < 0.8) {
                        // diffuse
                        color albedo = color::random() * color::random();
                        sphere_material = { Lambertian, { static_cast<float>(albedo.x()), static_cast<float>(albedo.y()), static_cast<float>(albedo.z()) }, 0.0f, 0.0f };
                        sphere[index] = { { static_cast<float>(center.x()), static_cast<float>(center.y()), static_cast<float>(center.z()) }, 0.2, sphere_material };
                    } else if (choose_mat < 0.95) {
                        // metal
                        color albedo = color::random(0.5, 1);
                        double fuzz = random_double(0, 0.5);
                        sphere_material = { Metal, { static_cast<float>(albedo.x()), static_cast<float>(albedo.y()), static_cast<float>(albedo.z()) }, static_cast<float>(fuzz), 0.0f };
                        sphere[index] = { { static_cast<float>(center.x()), static_cast<float>(center.y()), static_cast<float>(center.z()) }, 0.2, sphere_material };
                    } else {
                        // glass
                        sphere_material = { Dielectric, { 0.0f, 0.0f, 0.0f }, 0.0f, 1.5f };
                        sphere[index] = { { static_cast<float>(center.x()), static_cast<float>(center.y()), static_cast<float>(center.z()) }, 0.2, sphere_material };
                    }
                }
                index++;
                if (index > 200) break;
            }
        }

        hittable_list world;
        world.sphere_count = 200;
        std::memcpy(world.spheres, sphere, sizeof(sphere));

        std::cout << "\nCPU Sphere Data Before Buffer Creation:" << std::endl;
        printSphereData(world.spheres, world.sphere_count);

        id<MTLBuffer> worldBuffer = [device newBufferWithBytes:&world length:sizeof(hittable_list) options:MTLResourceStorageModeShared];

        // Debugging: Check if world buffer is correctly populated
        hittable_list* gpu_spheres = static_cast<hittable_list*>([worldBuffer contents]);
        std::cout << "\nGPU Sphere Data After Buffer Creation:" << std::endl;
        printSphereData(gpu_spheres->spheres, gpu_spheres->sphere_count);
    
        id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

        [computeEncoder setComputePipelineState:pipelineState];
        [computeEncoder setBuffer:pixelBuffer offset:0 atIndex:0];
        [computeEncoder setBuffer:cameraBuffer offset:0 atIndex:1];
        [computeEncoder setBuffer:worldBuffer offset:0 atIndex:2];
        [computeEncoder setBytes:&image_width length:sizeof(image_width) atIndex:3];
        [computeEncoder setBytes:&image_height length:sizeof(image_height) atIndex:4];
        [computeEncoder setBytes:&samples_per_pixel length:sizeof(samples_per_pixel) atIndex:5];
        [computeEncoder setBytes:&max_depth length:sizeof(max_depth) atIndex:6];

        MTLSize gridSize = MTLSizeMake(image_width, image_height, 1);
        NSUInteger threadGroupSize = pipelineState.maxTotalThreadsPerThreadgroup;
        MTLSize threadGroupSizeDim = MTLSizeMake(threadGroupSize, 1, 1);
        [computeEncoder dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSizeDim];

        [computeEncoder endEncoding];
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        float* pixelData = (float*)[pixelBuffer contents];

        static const interval intensity(0.000, 0.999);

        std::ofstream outFile("output.ppm");
        outFile << "P3\n" << image_width << ' ' << image_height << "\n255\n";
        for (int j = 0; j < image_height; ++j) {
            for (int i = 0; i < image_width; ++i) {
                int index = 3 * (j * image_width + i);
                if(i==0 && j==0)
                    printf("\npixel00_loc from gpu : %f, %f, %f\n", pixelData[index], pixelData[index+1], pixelData[index+2]);
                    // printf("\n%f %f\n", pixelData[index], intensity.clamp(linear_to_gamma(pixelData[index])));
                int ir = static_cast<int>(255.999 * intensity.clamp(linear_to_gamma(pixelData[index])));
                int ig = static_cast<int>(255.999 * intensity.clamp(linear_to_gamma(pixelData[index + 1])));
                int ib = static_cast<int>(255.999 * intensity.clamp(linear_to_gamma(pixelData[index + 2])));

                outFile << ir << ' ' << ig << ' ' << ib << '\n';
            }
        }
        outFile.close();

        std::cout << "\nImage saved to output.ppm" << std::endl;
    }

    return 0;
}
