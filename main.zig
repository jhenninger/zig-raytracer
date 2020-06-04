const std = @import("std");
const math = std.math;
const io = std.io;
const rand = std.rand;
const heap = std.heap;
const Allocator = std.mem.Allocator;
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

fn writeColor(color: Vec3, out: var) !void {
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

pub fn randomScene(random: *Random, allocator: *Allocator) !HittableList {
    const gridSize = 28;
    var list = try ArrayList(Sphere).initCapacity(allocator, gridSize * gridSize + 4);

    const large_radius = 1;
    const large_spheres = [_]Sphere{
        Sphere.new(Vec3.new(0, 1, 0), large_radius, Material.dielectric(1.5)),
        Sphere.new(Vec3.new(-4, 1, 0), large_radius, Material.lambertian(Vec3.new(0.4, 0.2, 0.1))),
        Sphere.new(Vec3.new(4, 1, 0), large_radius, Material.metal(Vec3.new(0.7, 0.6, 0.5), 0.0)),
    };
    try list.appendSlice(&large_spheres);

    const small_radius = 0.2;

    var x: i32 = -gridSize / 2;
    while (x < gridSize / 2) : (x += 1) {
        var z: i32 = -gridSize / 2;
        inner: while (z < gridSize / 2) : (z += 1) {
            const center = Vec3.new(@intToFloat(f64, x) + random.float(f64), small_radius, @intToFloat(f64, z) + random.float(f64));

            // don't create spheres that are too close to each other
            for (list.items) |sphere| {
                if (center.sub(sphere.center).length() < sphere.radius * 1.05 + small_radius) {
                    continue :inner;
                }
            }

            const choose_mat = random.float(f64);
            var material: Material = undefined;

            if (choose_mat < 0.6) {
                // diffuse
                const albedo = Vec3.rand(random).mulVec(Vec3.rand(random));
                material = Material.lambertian(albedo);
            } else if (choose_mat < 0.92) {
                // metal
                const albedo = Vec3.randomRange(random, 0.5, 1);
                const fuzz = random.float(f64) / 2;
                material = Material.metal(albedo, fuzz);
            } else {
                // glass
                material = Material.dielectric(1.5);
            }

            try list.append(Sphere.new(center, small_radius, material));
        }
    }

    const ground = Sphere.new(Vec3.new(0, -1000, 0), 1000, Material.lambertian(Vec3.new(0.5, 0.5, 0.5)));
    try list.append(ground);

    return HittableList{ .list = list };
}

pub fn main() !void {
    const stdout = io.getStdOut().outStream();
    const stderr = io.getStdErr().outStream();

    try stdout.print("P3\n{}\n{}\n{}\n", .{ image_width, image_height, max_color });

    var prng = rand.DefaultPrng.init(0);
    const random = &prng.random;

    const look_from = Vec3.new(13, 2, 3);
    const look_at = Vec3.new(0, 0, 0);
    const vup = Vec3.new(0, 1, 0);
    const focus_distance = 10.0;
    const aperture = 0.1;
    const fov = 20;

    const camera = Camera.new(look_from, look_at, vup, fov, aspect_ratio, aperture, focus_distance);

    const allocator = std.heap.page_allocator;
    const world = try randomScene(random, allocator);
    defer world.deinit();

    var y: i32 = image_height;
    while (y >= 0) : (y -= 1) {
        try stderr.print("\rScanlines remaining: {}      ", .{@intCast(u32, y)});
        var x: i32 = 0;
        while (x < image_width) : (x += 1) {
            var color = Vec3.zero();
            var s: i32 = 0;
            while (s < samples_per_pixel) : (s += 1) {
                const u = (@intToFloat(f64, x) + random.float(f64)) / @intToFloat(f64, image_width);
                const v = (@intToFloat(f64, y) + random.float(f64)) / @intToFloat(f64, image_height);
                const ray = camera.getRay(u, v, random);

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
