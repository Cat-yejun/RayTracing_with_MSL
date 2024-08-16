#ifndef CAMERA_H
#define CAMERA_H

#include "rtweekend.h"

class camera {
public:
    double aspect_ratio   = 16.0 / 9.0; // Ratio of image width over height
    int image_width       = 1600; // Rendered image width in pixel count
    int image_height      = 0;
    int samples_per_pixel = 100; // Count of random samples for each pixel
    int max_depth         = 50; // Maximum number of ray bounces into scene

    double vfov     = 90;
    point3 lookfrom = point3(0, 0, 0);
    point3 lookat   = point3(0, 0, -1);
    vec3   vup      = vec3(0, 1, 0);

    double defocus_angle = 0;
    double focus_dist = 10;

    point3 center;
    point3 pixel00_loc;
    vec3 pixel_delta_u;
    vec3 pixel_delta_v;
    vec3 defocus_disk_u;
    vec3 defocus_disk_v;

    void initialize() {
        image_height = static_cast<int>(image_width / aspect_ratio);
        image_height = (image_height < 1) ? 1 : image_height;
        
        // center = point3(0, 0, 0);
        center = lookfrom;

        // auto focal_length = 1.0;
        // auto focal_length = (lookfrom - lookat).length();
        auto theta = degrees_to_radians(vfov);
        auto h = std::tan(theta/2);
        // auto viewport_height = 2.0;
        // auto viewport_height = 2 * h * focal_length;
        auto viewport_height = 2 * h * focus_dist;
        auto viewport_width = viewport_height * aspect_ratio;

        w = unit_vector(lookfrom - lookat);
        u = unit_vector(cross(vup, w));
        v = cross(w, u);

        // auto viewport_u = vec3(viewport_width, 0, 0);
        // auto viewport_v = vec3(0, -viewport_height, 0);

        vec3 viewport_u = viewport_width * u;
        vec3 viewport_v = viewport_height * -v;

        pixel_delta_u = viewport_u / image_width;
        pixel_delta_v = viewport_v / image_height;

        // auto viewport_upper_left = center - vec3(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
        // auto viewport_upper_left = center - (focal_length * w) - viewport_u/2 - viewport_v/2;
        auto viewport_upper_left = center - (focus_dist * w) - viewport_u/2 - viewport_v/2;
        pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
    
        auto defocus_radius = focus_dist * std::tan(degrees_to_radians(defocus_angle / 2));
        defocus_disk_u = u * defocus_radius;
        defocus_disk_v = v * defocus_radius;
    }

private:
    vec3 u, v, w;

};

#endif
