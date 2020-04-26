const std = @import("std");
const math = std.math;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;

const HitRecord = struct {
    point: Vec3,
    normal: Vec3,
    frontFace: bool,
    distance: f64,

    pub fn new(distance: f64, point: Vec3, outwardNormal: Vec3, ray: Ray) HitRecord {
        const frontFace = ray.direction.dot(outwardNormal) < 0;

        return HitRecord{
            .point = point,
            .normal = if (frontFace) outwardNormal else outwardNormal.mul(-1),
            .frontFace = frontFace,
            .distance = distance,
        };
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f64,

    pub fn new(center: Vec3, radius: f64) Sphere {
        return Sphere{
            .center = center,
            .radius = radius,
        };
    }

    pub fn hit(self: Sphere, ray: Ray, tmin: f64, tmax: f64) ?HitRecord {
        const oc = ray.origin.sub(self.center);
        const a = ray.direction.lengthSquared();
        const halfB = ray.direction.dot(oc);
        const c = oc.lengthSquared() - self.radius * self.radius;
        const discriminant = halfB * halfB - a * c;

        if (discriminant > 0) {
            const root = math.sqrt(discriminant);
            var t = (-halfB - root) / a;
            if (t > tmin and t < tmax) {
                const point = ray.at(t);
                return HitRecord.new(t, point, point.sub(self.center).div(self.radius), ray);
            }
            t = (-halfB + root) / a;
            if (t > tmin and t < tmax) {
                const point = ray.at(t);
                return HitRecord.new(t, point, point.sub(self.center).div(self.radius), ray);
            }
        }
        return null;
    }
};

pub const HittableList = struct {
    objects: []const Sphere,

    pub fn hit(self: HittableList, ray: Ray, tmin: f64, tmax: f64) ?HitRecord {
        var record: ?HitRecord = null;
        var closest = tmax;

        for (self.objects) |hittable| {
            if (hittable.hit(ray, tmin, closest)) |current| {
                record = current;
                closest = current.distance;
            }
        }

        return record;
    }
};