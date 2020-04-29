const std = @import("std");
const Random = std.rand.Random;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const HitRecord = @import("hittable.zig").HitRecord;

const Scatter = struct {
    attenuation: Vec3,
    ray: Ray,
};

pub const Material = union(enum) {
    Lambertian: Lambertian,
    Metal: Metal,

    pub fn scatter(self: Material, ray: Ray, record: HitRecord, random: *Random) ?Scatter {
        return switch (self) {
            .Lambertian => |m| m.scatter(record, random),
            .Metal => |m| m.scatter(ray, record),
        };
    }

    pub fn lambertian(albedo: Vec3) Material {
        return Material {
            .Lambertian = Lambertian { 
                .albedo = albedo
            }
        };
    }

    pub fn metal(albedo: Vec3) Material {
        return Material {
            .Metal = Metal {
                .albedo = albedo
            }
        };
    }
};

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn scatter(self: Lambertian, record: HitRecord, random: *Random) ?Scatter {
        const scatter_direction = record.normal.add(Vec3.randomUnitVector(random));
        return Scatter {
            .ray = Ray.new(record.point, scatter_direction),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Vec3,

    pub fn scatter(self: Metal, ray: Ray, record: HitRecord) ?Scatter {
        const reflected = reflect(ray.direction.unit(), record.normal);
        return Scatter {
            .ray = Ray.new(record.point, reflected),
            .attenuation = self.albedo,
        };
    }
};


fn reflect(vector: Vec3, normal: Vec3) Vec3 {
    const dot = vector.dot(normal);
    return vector.sub(normal.mul(2 * dot));
}