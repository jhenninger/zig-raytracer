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

const factor = 2;
const imageWidth = 200 * factor;
const imageHeight = 100 * factor;
const maxColor = 255;
const samplesPerPixel = 100;
const maxDepth = 50;

const Camera = struct {
    origin: Vec3,
    lowerLeftCorner: Vec3,
    horizonal: Vec3,
    vertical: Vec3,

    pub fn new() Camera {
        return Camera{
            .origin = Vec3.zero(),
            .lowerLeftCorner = Vec3.new(-2, -1, -1),
            .horizonal = Vec3.new(4, 0, 0),
            .vertical = Vec3.new(0, 2, 0),
        };
    }

    pub fn getRay(self: Camera, u: f64, v: f64) Ray {
        return Ray.new(self.origin, self.lowerLeftCorner.add(self.horizonal.mul(u)).add(self.vertical.mul(v)));
    }
};

fn rayColor(ray: Ray, depth: i32, world: HittableList, random: *Random) Vec3 {
    if (depth <= 0) return Vec3.zero();

    if (world.hit(ray, 0.001, math.inf(f64))) |hit| {
        const target = hit.point.add(hit.normal).add(Vec3.randomUnitVector(random));
        return rayColor(Ray.new(hit.point, target.sub(hit.point)), depth - 1, world, random).mul(0.5);
    }

    const unitDirection = ray.direction.unit();
    const t = 0.5 * (unitDirection.y + 1);
    const white = Vec3.new(1, 1, 1).mul(1 - t);
    const blue = Vec3.new(0.5, 0.7, 1).mul(t);
    return white.add(blue);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().outStream();
    const stderr = std.io.getStdErr().outStream();

    try stdout.print("P3\n{}\n{}\n{}\n", .{ imageWidth, imageHeight, maxColor });

    var prng: rand.DefaultPrng =  rand.DefaultPrng.init(0);

    const camera = Camera.new();

    const spheres = &[_]Sphere{
        Sphere.new(Vec3.new(0, 0, -1), 0.5),
        Sphere.new(Vec3.new(0, -100.5, -1), 100),
    };

    const world = HittableList{ .objects = spheres };

    var y: i32 = imageHeight;
    while (y >= 0) : (y -= 1) {
        try stderr.print("\rScanlines remaining: {}      ", .{@intCast(u32, y)});
        var x: i32 = 0;
        while (x < imageWidth) : (x += 1) {
            var color = Vec3.zero();
            var s: i32 = 0;
            while (s < samplesPerPixel) : (s += 1) {
                const u = (@intToFloat(f64, x) + prng.random.float(f64)) / imageWidth;
                const v = (@intToFloat(f64, y) + prng.random.float(f64)) / imageHeight;
                const ray = camera.getRay(u, v);
                color.addAssign(rayColor(ray, maxDepth, world, &prng.random));
            }
            try color.write(stdout, samplesPerPixel, maxColor);
        }
    }
}