const std = @import("std");
const math = std.math;
const Random = std.rand.Random;

const Vec3 = @import("vec3.zig").Vec3;
const Ray = @import("ray.zig").Ray;

pub const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    horizontal: Vec3,
    vertical: Vec3,
    u: Vec3,
    v: Vec3,
    w: Vec3,
    lens_radius: f64,

    pub fn new(look_from: Vec3, look_at: Vec3, vup: Vec3, vfov: f64, aspect_ratio: f64, aperture: f64, focus_distance: f64) Camera {
        const theta = toRadians(vfov);
        const h = math.tan(theta / 2);
        const viewport_height = 2 * h;
        const viewport_width = aspect_ratio * viewport_height;

        const w = look_from.sub(look_at).unit();
        const u = vup.cross(w).unit();
        const v = w.cross(u);

        const horizontal = u.mul(viewport_width).mul(focus_distance);
        const vertical = v.mul(viewport_height).mul(focus_distance);
        const lower_left_corner = look_from.sub(horizontal.div(2)).sub(vertical.div(2)).sub(w.mul(focus_distance));

        return Camera{
            .origin = look_from,
            .lower_left_corner = lower_left_corner,
            .horizontal = horizontal,
            .vertical = vertical,
            .u = u,
            .v = v,
            .w = w,
            .lens_radius = aperture / 2,
        };
    }

    pub fn getRay(self: Camera, s: f64, t: f64, random: Random) Ray {
        const rd = Vec3.randomInUnitDisk(random).mul(self.lens_radius);
        const offset = self.u.mul(rd.x).add(self.v.mul(rd.y));

        const direction = self.lower_left_corner.add(self.horizontal.mul(s)).add(self.vertical.mul(t)).sub(self.origin).sub(offset);
        return Ray.new(self.origin.add(offset), direction);
    }
};

fn toRadians(degrees: f64) f64 {
    return degrees * (math.pi / 180.0);
}
