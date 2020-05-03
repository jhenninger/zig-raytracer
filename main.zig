const std = @import("std");
const math = std.math;
const io = std.io;
const rand = std.rand;
const Random = rand.Random;
const ArrayList = std.ArrayList;

const Vec3 = @import("vec3.zig").Vec3;

const hittable = @import("hittable.zig");
const Sphere = hittable.Sphere;
const HittableList = hittable.HittableList;

const Ray = @import("ray.zig").Ray;

const Material = @import("material.zig").Material;

const factor = 2;
const image_width = 200 * factor;
const image_height = 100 * factor;
const max_color = 255;
const samples_per_pixel = 100;
const max_depth = 50;

const Camera = struct {
    origin: Vec3,
    lower_left_corner: Vec3,
    horizonal: Vec3,
    vertical: Vec3,

    pub fn new() Camera {
        return Camera{
            .origin = Vec3.zero(),
            .lower_left_corner = Vec3.new(-2, -1, -1),
            .horizonal = Vec3.new(4, 0, 0),
            .vertical = Vec3.new(0, 2, 0),
        };
    }

    pub fn getRay(self: Camera, u: f64, v: f64) Ray {
        return Ray.new(self.origin, self.lower_left_corner.add(self.horizonal.mul(u)).add(self.vertical.mul(v)));
    }
};

fn rayColor(ray: Ray, depth: i32, world: HittableList, random: *Random) Vec3 {
    if (depth <= 0) return Vec3.zero();

    if (world.hit(ray, 0.001, math.inf(f64))) |hit| {
        if (hit.material.scatter(ray, hit, random)) |scatter| {
            return scatter.attenuation.mulVec(rayColor(scatter.ray, depth - 1, world, random));
        }

        return Vec3.zero();
    }

    const unit_direction = ray.direction.unit();
    const t = 0.5 * (unit_direction.y + 1);
    const white = Vec3.new(1, 1, 1).mul(1 - t);
    const blue = Vec3.new(0.5, 0.7, 1).mul(t);
    return white.add(blue);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();
    const stderr = std.io.getStdErr().outStream();

    try stdout.print("P3\n{}\n{}\n{}\n", .{ image_width, image_height, max_color });

    var prng = rand.DefaultPrng.init(0);

    const camera = Camera.new();

    const spheres = &[_]Sphere{
        Sphere.new(Vec3.new(0, 0, -1), 0.5, Material.lambertian(Vec3.new(0.1, 0.2, 0.5))),
        Sphere.new(Vec3.new(0, -100.5, -1), 100, Material.lambertian(Vec3.new(0.8, 0.8, 0.0))),
        Sphere.new(Vec3.new(1, 0, -1), 0.5, Material.metal(Vec3.new(0.8, 0.6, 0.2), 0.3)),
        Sphere.new(Vec3.new(-1, 0, -1), 0.5, Material.dielectric(1.5)),
        Sphere.new(Vec3.new(-1, 0, -1), -0.45, Material.dielectric(1.5)),
    };

    const world = HittableList{ .objects = spheres };

    var y: i32 = image_height;
    while (y >= 0) : (y -= 1) {
        try stderr.print("\rScanlines remaining: {}      ", .{@intCast(u32, y)});
        var x: i32 = 0;
        while (x < image_width) : (x += 1) {
            var color = Vec3.zero();
            var s: i32 = 0;
            while (s < samples_per_pixel) : (s += 1) {
                const u = (@intToFloat(f64, x) + prng.random.float(f64)) / image_width;
                const v = (@intToFloat(f64, y) + prng.random.float(f64)) / image_height;
                const ray = camera.getRay(u, v);
                color.addAssign(rayColor(ray, max_depth, world, &prng.random));
            }
            try color.write(stdout, samples_per_pixel, max_color);
        }
    }
}
