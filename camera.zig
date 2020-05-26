const std = @import("std");
const math = std.math;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;

pub const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,

    pub fn new(vfov: f64, aspect_ratio: f64) Camera {
        const theta = to_radians(vfov);
        const h = math.tan(theta / 2);
        const viewport_height = 2 * h;
        const viewport_width = aspect_ratio * viewport_height;

        const focal_length = 1.0;
        const origin = Vec3.zero();
        const horizontal = Vec3.new(viewport_width, 0, 0);
        const vertical = Vec3.new(0, viewport_height, 0);
        const lower_left_corner = origin.sub(Vec3.new(0, 0, focal_length)).sub(vertical.div(2)).sub(horizontal.div(2));

        return Camera{
            .origin = origin,
            .lower_left_corner = lower_left_corner,
            .horizontal = horizontal,
            .vertical = vertical,
        };
    }

    pub fn getRay(self: Camera, u: f64, v: f64) Ray {
        return Ray.new(self.origin, self.lower_left_corner.add(self.horizontal.mul(u)).add(self.vertical.mul(v)).sub(self.origin));
    }
};

fn to_radians(rads: f64) f64 {
    return rads * (math.pi / 180.0);
}
