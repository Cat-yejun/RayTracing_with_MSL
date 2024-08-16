#include <metal_stdlib>
using namespace metal;

#define M_PI 3.14159265358979323846

float random_float(thread uint& seed) {
    seed = 1664525 * seed + 1013904223;
    return static_cast<float>(seed & 0x00FFFFFF) / static_cast<float>(0x01000000);
}

float3 random_in_unit_disk(thread uint& seed) {
    while(true) {
        float3 p = float3(random_float(seed) * 2.0 - 1.0, random_float(seed) * 2.0 - 1.0, 0.0);
        if (dot(p, p) < 1)
            return p;
    }
}

struct ray {
    float3 origin;
    float3 direction;

    ray() : origin(float3(0)), direction(float3(0)) {}
    ray(float3 origin, float3 direction) : origin(origin), direction(direction) {}

    float3 at(float t) const {
        return origin + direction * t;
    }
};

enum MaterialType {
    Lambertian,
    Metal,
    Dielectric
};

struct hit_record;

struct My_Material {
    int material_type;
    float3 albedo;
    float fuzz;
    float refraction_index;

    bool scatter(const thread ray& r_in, const thread hit_record& rec, thread float3& attenuation, thread ray& scattered, thread uint& seed);
};

struct hit_record {
    float3 p;
    float3 normal;
    float t;
    bool front_face;
    My_Material mat;

    void set_face_normal(const thread ray& r, const float3 outward_normal) {
        front_face = dot(r.direction, outward_normal) < 0;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

float3 random_unit_vector(thread uint& seed) {
    float3 p;

    while (true) {
        p = float3(random_float(seed) * 2.0 - 1.0,
                   random_float(seed) * 2.0 - 1.0,
                   random_float(seed) * 2.0 - 1.0);
        if (dot(p, p) < 1.0)
            break;
    }

    return p / length(p);
}

float3 my_reflect(const float3 v, const float3 n) {
    return v - 2.0 * dot(v, n) * n;
}

float3 my_refract(const float3 uv, const float3 n, float etai_over_etat) {
    float cos_theta = fmin(dot(-uv, n), 1.0);
    float3 r_out_perp = (uv + n * cos_theta) * etai_over_etat;
    float3 r_out_parallel = n * -sqrt(fabs(1.0 - dot(r_out_perp, r_out_perp)));
    return r_out_perp + r_out_parallel;
}

float reflectance(float cosine, float ref_idx) {
    auto r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * pow((1 - cosine), 5);
}

bool My_Material::scatter(const thread ray& r_in, const thread hit_record& rec, thread float3& attenuation, thread ray& scattered, thread uint& seed) {
    if (material_type == Lambertian) {
        float3 scatter_direction = rec.normal + random_unit_vector(seed);

        if (length(scatter_direction) < 1e-8)
            scatter_direction = rec.normal;

        scattered = ray(rec.p, scatter_direction);
        attenuation = this->albedo;

        return true;

    } else if (material_type == Metal) {
        float3 reflected = my_reflect(r_in.direction, rec.normal);
        scattered = ray(rec.p, reflected/length(reflected) + fuzz * random_unit_vector(seed));
        attenuation = albedo;
        
        return (dot(scattered.direction, rec.normal) > 0);

    } else if (material_type == Dielectric) {
        attenuation = float3(1.0, 1.0, 1.0);
        float eta = rec.front_face ? (1.0 / refraction_index) : refraction_index;
        float3 unit_direction = normalize(r_in.direction);
        float cos_theta = fmin(dot(-unit_direction, rec.normal), 1.0);
        float sin_theta = sqrt(1.0 - cos_theta * cos_theta);

        bool cannot_refract = eta * sin_theta > 1.0;
        float3 direction;

        if (cannot_refract || reflectance(cos_theta, eta) > random_float(seed))
            direction = my_reflect(unit_direction, rec.normal);
        else
            direction = my_refract(unit_direction, rec.normal, eta);
        scattered = ray(rec.p, direction);

        return true;
    }

    return false;
}

struct Sphere {
    float3 center;
    float radius;
    My_Material mat;

    bool hit_sphere(const thread ray& r, float t_min, float t_max, thread hit_record* rec) const;
};

struct hittable_list {
    Sphere spheres[200];
    int sphere_count;

    bool hit_world(const thread ray& r, float t_min, float t_max, thread hit_record& rec) const;
};

struct Camera {
    float3 center;
    float3 pixel00_loc;
    float3 pixel_delta_u;
    float3 pixel_delta_v;
    float defocus_angle;
    float3 defocus_disk_u;
    float3 defocus_disk_v;

    float3 defocus_disk_sample(thread uint& seed) const;
    ray get_ray(int i, int j, thread uint& seed);
};

float3 Camera::defocus_disk_sample(thread uint& seed) const {
    float3 p = random_in_unit_disk(seed);
    return this->center + (p.x * this->defocus_disk_u) + (p.y * this->defocus_disk_v);
}

ray Camera::get_ray(int i, int j, thread uint& seed) {
    float3 offset = float3(random_float(seed) - 0.5, random_float(seed) - 0.5, 0);
    float3 pixel_sample = this->pixel00_loc + (i + offset.x) * this->pixel_delta_u + (j + offset.y) * this->pixel_delta_v;
    //float3 ray_origin = this->center;
    float3 ray_origin = (this->defocus_angle <= 0) ? this->center : defocus_disk_sample(seed);
    float3 ray_direction = pixel_sample - ray_origin;

    return ray(ray_origin, ray_direction);
}

bool Sphere::hit_sphere(const thread ray& r, float t_min, float t_max, thread hit_record* rec) const {
    float3 oc = this->center - r.origin;
    float a = dot(r.direction, r.direction);
    float half_b = dot(oc, r.direction);
    float c = dot(oc, oc) - this->radius * this->radius;

    float discriminant = half_b * half_b - a * c;

    if (discriminant < 0) {
        return false;
    } 

    float sqrtd = sqrt(discriminant);

    float root = (half_b - sqrtd) / a;

    if (root < t_min || root > t_max) {
        root = (half_b + sqrtd) / a;
        if (root < t_min || root > t_max) {
            return false;
        }
    }

    rec->t = root;
    rec->p = r.at(rec->t);
    float3 outward_normal = (rec->p - this->center) / this->radius;
    rec->set_face_normal(r, outward_normal);
    rec->mat = this->mat;

    return true;
}

bool hittable_list::hit_world(const thread ray& r, float t_min, float t_max, thread hit_record& rec) const {
    hit_record temp_rec;
    bool hit_anything = false;
    float closest_so_far = t_max;

    for (int i = 0; i < this->sphere_count; i++) {
        if (this->spheres[i].hit_sphere(r, t_min, closest_so_far, &temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }

    return hit_anything;
}

float3 ray_color(const thread ray& initial_ray, int max_depth, hittable_list world, thread uint& seed) {
    float3 accumulated_color = float3(1.0, 1.0, 1.0); // 초기 누적 색상
    ray current_ray = initial_ray;
    int depth = max_depth;

    while (depth > 0) {
        hit_record rec;

        if (world.hit_world(current_ray, 0.001, INFINITY, rec)) {
            ray scattered;
            float3 attenuation;
            if (rec.mat.scatter(current_ray, rec, attenuation, scattered, seed)) {
                accumulated_color *= attenuation;
                current_ray = scattered; // 다음 광선을 설정
            } else {
                accumulated_color = float3(0.0, 0.0, 0.0);
                break; // 산란되지 않으면 루프를 종료
            }
        } else {
            float3 unit_direction = normalize(current_ray.direction);
            float t = 0.5 * (unit_direction.y + 1.0);
            float3 background_color = (1.0 - t) * float3(1.0, 1.0, 1.0) + t * float3(0.5, 0.7, 1.0);
            accumulated_color *= background_color;
            break; // 백그라운드에 도달하면 루프를 종료
        }

        depth--;
    }

    return accumulated_color;
}


My_Material test(const thread ray& r, int depth, hittable_list world){
    hit_record rec;

    world.hit_world(r, 0.001, INFINITY, rec);

    My_Material my_mat = rec.mat;

    return my_mat;
}

kernel void render(device float* pixel_data [[ buffer(0) ]],
                   constant Camera* cam [[ buffer(1) ]],
                   constant hittable_list* world [[ buffer(2) ]],
                   constant uint* width [[ buffer(3) ]],
                   constant uint* height [[ buffer(4) ]],
                   constant uint* samples_per_pixel [[ buffer(5) ]],
                   constant uint* max_depth [[ buffer(6) ]],
                   uint2 gid [[ thread_position_in_grid ]]) {
    if (gid.x >= *width || gid.y >= *height) return;

    int i = gid.x;
    int j = gid.y;
    float3 pixel_color(0, 0, 0);
    thread uint seed = gid.x + gid.y * *width;

    Camera My_Cam = *cam;
    
    for (int sample = 0; sample < *samples_per_pixel; sample++) {
        ray r = My_Cam.get_ray(i, j, seed);
        pixel_color += ray_color(r, *max_depth, *world, seed);
    }

    //ray r = get_ray(800, 450, seed, *cam);
    //My_Material foo = test(r, *max_depth, *world);

    pixel_color /= static_cast<float>(*samples_per_pixel);
    int index = 3 * (j * (*width) + i);
    pixel_data[index + 0] = pixel_color.x;
    pixel_data[index + 1] = pixel_color.y;
    pixel_data[index + 2] = pixel_color.z;
    //pixel_data[index + 0] = foo.albedo.x;
    //pixel_data[index + 1] = foo.albedo.y;
    //pixel_data[index + 2] = foo.albedo.z;

}
