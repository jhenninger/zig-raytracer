const std = @import("std");
const Random = std.rand.Random;
const math = std.math;

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
    Dielectric: Dielectric,

    pub fn scatter(self: Material, ray: Ray, record: HitRecord, random: *Random) ?Scatter {
        return switch (self) {
            .Lambertian => |m| m.scatter(record, random),
            .Metal => |m| m.scatter(ray, record, random),
            .Dielectric => |m| m.scatter(ray, record, random),
        };
    }

    pub fn lambertian(albedo: Vec3) Material {
        return Material{
            .Lambertian = Lambertian{ .albedo = albedo },
        };
    }

    pub fn metal(albedo: Vec3, fuzz: f64) Material {
        return Material{
            .Metal = Metal{
                .albedo = albedo,
                .fuzz = fuzz,
            },
        };
    }

    pub fn dielectric(ref_idx: f64) Material {
        return Material{
            .Dielectric = Dielectric{ .ref_idx = ref_idx },
        };
    }
};

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn scatter(self: Lambertian, record: HitRecord, random: *Random) ?Scatter {
        const scatter_direction = record.normal.add(Vec3.randomUnitVector(random));
        return Scatter{
            .ray = Ray.new(record.point, scatter_direction),
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Vec3,
    fuzz: f64,

    pub fn scatter(self: Metal, ray: Ray, record: HitRecord, random: *Random) ?Scatter {
        const reflected = reflect(ray.direction.unit(), record.normal).add(Vec3.randomInUnitSphere(random).mul(self.fuzz));
        if (reflected.dot(record.normal) <= 0) return null;
        return Scatter{
            .ray = Ray.new(record.point, reflected),
            .attenuation = self.albedo,
        };
    }
};

pub const Dielectric = struct {
    ref_idx: f64,

    pub fn scatter(self: Dielectric, ray: Ray, record: HitRecord, random: *Random) ?Scatter {
        const etai_over_etat = if (record.front_face) 1 / self.ref_idx else self.ref_idx;
        const unit_direction = ray.direction.unit();
        const cos_theta = math.min(unit_direction.neg().dot(record.normal), 1);
        const sin_theta = math.sqrt(1.0 - cos_theta * cos_theta);

        const direction = if (etai_over_etat * sin_theta > 1.0 or random.float(f64) < schlick(cos_theta, etai_over_etat))
            reflect(unit_direction, record.normal)
        else
            refract(unit_direction, record.normal, etai_over_etat);

        return Scatter{
            .attenuation = Vec3.one(),
            .ray = Ray.new(record.point, direction),
        };
    }
};

fn reflect(vector: Vec3, normal: Vec3) Vec3 {
    const dot = vector.dot(normal);
    return vector.sub(normal.mul(2 * dot));
}

fn refract(vector: Vec3, normal: Vec3, etai_over_etat: f64) Vec3 {
    const cos_theta = vector.neg().dot(normal);
    const refracted_parallel = vector.add(normal.mul(cos_theta)).mul(etai_over_etat);
    const refrated_perp = normal.neg().mul(math.sqrt(1.0 - refracted_parallel.lengthSquared()));
    return refracted_parallel.add(refrated_perp);
}

fn schlick(cos: f64, ref_idx: f64) f64 {
    var r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 *= r0;
    return r0 + (1 - r0) * math.pow(f64, 1 - cos, 5);
}
