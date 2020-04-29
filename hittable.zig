const std = @import("std");
const math = std.math;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;
const Material = @import("material.zig").Material;

pub const HitRecord = struct {
    point: Vec3,
    normal: Vec3,
    front_face: bool,
    distance: f64,
    material: *const Material,

    pub fn new(distance: f64, point: Vec3, outwardNormal: Vec3, ray: Ray, material: *const Material) HitRecord {
        const front_face = ray.direction.dot(outwardNormal) < 0;

        return HitRecord{
            .point = point,
            .normal = if (front_face) outwardNormal else outwardNormal.mul(-1),
            .front_face = front_face,
            .distance = distance,
            .material = material,
        };
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f64,
    material: Material,

    pub fn new(center: Vec3, radius: f64, material: Material) Sphere {
        return Sphere{
            .center = center,
            .radius = radius,
            .material = material,
        };
    }

    pub fn hit(self: Sphere, ray: Ray, tmin: f64, tmax: f64) ?HitRecord {
        const oc = ray.origin.sub(self.center);
        const a = ray.direction.lengthSquared();
        const half_b = ray.direction.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;

        if (discriminant > 0) {
            const root = math.sqrt(discriminant);
            var t = (-half_b - root) / a;
            if (t > tmin and t < tmax) {
                const point = ray.at(t);
                return HitRecord.new(t, point, point.sub(self.center).div(self.radius), ray, &self.material);
            }
            t = (-half_b + root) / a;
            if (t > tmin and t < tmax) {
                const point = ray.at(t);
                return HitRecord.new(t, point, point.sub(self.center).div(self.radius), ray, &self.material);
            }
        }
        return null;
    }
};

pub const HittableList = struct {
    objects: []const Sphere,

    pub fn hit(self: HittableList, ray: Ray, t_min: f64, t_max: f64) ?HitRecord {
        var record: ?HitRecord = null;
        var closest = t_max;

        // iterating by reference is important here, otherwise we will store a wrong pointer to
        // the object's Material in the HitRecord
        for (self.objects) |*hittable| {
            if (hittable.hit(ray, t_min, closest)) |current| {
                record = current;
                closest = current.distance;
            }
        }

        return record;
    }
};