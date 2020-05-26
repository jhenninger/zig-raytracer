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
const Camera = @import("camera.zig").Camera;

const Material = @import("material.zig").Material;

const aspect_ratio: f64 = 16.0 / 9.0;
const image_width: u32 = 384;
const image_height = @floatToInt(u32, @intToFloat(f64, image_width) / aspect_ratio);
const max_color = 255;
const samples_per_pixel = 100;
const max_depth = 50;
const min_distance = 0.000001;

fn rayColor(ray: Ray, depth: i32, world: HittableList, random: *Random) Vec3 {
    if (depth <= 0) return Vec3.zero();

    if (world.hit(ray, min_distance, math.inf(f64))) |hit| {
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

fn rayDepth(ray: Ray, depth: i32, world: HittableList, random: *Random) Vec3 {
    if (depth <= 0) {
        return Vec3.one();
    }

    if (world.hit(ray, min_distance, math.inf(f64))) |hit| {
        if (hit.material.scatter(ray, hit, random)) |scatter| {
            return rayDepth(scatter.ray, depth - 1, world, random);
        }
    }

    return Vec3.one().mul(@intToFloat(f64, max_depth - depth) / @intToFloat(f64, max_depth));
}

fn rayNormal(ray: Ray, world: HittableList) Vec3 {
    if (world.hit(ray, min_distance, math.inf(f64))) |hit| {
        return hit.normal.add(Vec3.one()).mul(0.5);
    }

    return Vec3.zero();
}

fn rayAlbedo(ray: Ray, world: HittableList) Vec3 {
    if (world.hit(ray, min_distance, math.inf(f64))) |hit| {
        return switch (hit.material.*) {
            .Lambertian => |m| m.albedo,
            .Metal => |m| m.albedo,
            .Dielectric => Vec3.one(),
        };
    }

    return Vec3.zero();
}

pub fn writeColor(color: Vec3, out: var) !void {
    const samples = @intToFloat(f64, samples_per_pixel);
    const r = math.sqrt(color.x / samples);
    const g = math.sqrt(color.y / samples);
    const b = math.sqrt(color.z / samples);

    const max = @intToFloat(f64, max_color);
    try out.print("{} {} {}\n", .{
        @floatToInt(u8, r * max),
        @floatToInt(u8, g * max),
        @floatToInt(u8, b * max),
    });
}

pub fn main() !void {
    const stdout = io.getStdOut().outStream();
    const stderr = io.getStdErr().outStream();

    try stdout.print("P3\n{}\n{}\n{}\n", .{ image_width, image_height, max_color });

    var prng = rand.DefaultPrng.init(0);

    const camera = Camera.new(Vec3.new(-2, 2, 1), Vec3.new(0, 0, -1), Vec3.new(0, 1, 0), 20, aspect_ratio);

    const spheres = &[_]Sphere{
        Sphere.new(Vec3.new(0, 0, -1), 0.5, Material.lambertian(Vec3.new(0.1, 0.2, 0.5))),
        Sphere.new(Vec3.new(0, -100.5, -1), 100, Material.lambertian(Vec3.new(0.8, 0.8, 0.0))),
        Sphere.new(Vec3.new(1, 0, -1), 0.5, Material.metal(Vec3.new(0.8, 0.6, 0.2), 0.1)),
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
                const u = (@intToFloat(f64, x) + prng.random.float(f64)) / @intToFloat(f64, image_width);
                const v = (@intToFloat(f64, y) + prng.random.float(f64)) / @intToFloat(f64, image_height);
                const ray = camera.getRay(u, v);

                // const sample_color = rayNormal(ray, world);
                // const sample_color = rayAlbedo(ray, world);
                // const sample_color = rayDepth(ray, max_depth, world, &prng.random);
                const sample_color = rayColor(ray, max_depth, world, &prng.random);

                color.addAssign(sample_color);
            }
            try writeColor(color, stdout);
        }
    }
}
