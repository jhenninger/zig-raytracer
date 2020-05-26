const std = @import("std");
const math = std.math;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;

pub const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,

    pub fn new(look_from: Vec3, look_at: Vec3, vup: Vec3, vfov: f64, aspect_ratio: f64) Camera {
        const theta = to_radians(vfov);
        const h = math.tan(theta / 2);
        const viewport_height = 2 * h;
        const viewport_width = aspect_ratio * viewport_height;

        const w = look_from.sub(look_at).unit();
        const u = vup.cross(w).unit();
        const v = w.cross(u);

        const horizontal = u.mul(viewport_width);
        const vertical = v.mul(viewport_height);
        const lower_left_corner = look_from.sub(horizontal.div(2)).sub(vertical.div(2)).sub(w);

        return Camera{
            .origin = look_from,
            .lower_left_corner = lower_left_corner,
            .horizontal = horizontal,
            .vertical = vertical,
        };
    }

    pub fn getRay(self: Camera, u: f64, v: f64) Ray {
        return Ray.new(self.origin, self.lower_left_corner.add(self.horizontal.mul(u)).add(self.vertical.mul(v)).sub(self.origin));
    }
};

fn to_radians(degrees: f64) f64 {
    return degrees * (math.pi / 180.0);
}
