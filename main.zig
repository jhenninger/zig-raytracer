const std = @import("std");
const math = std.math;
const io = std.io;
const rand = std.rand;
const heap = std.heap;
const time = std.time;
const warn = std.debug.warn;
const Allocator = std.mem.Allocator;
const Random = rand.Random;
const ArrayList = std.ArrayList;
const Thread = std.Thread;
const AtomicInt = std.atomic.Int;

const Vec3 = @import("vec3.zig").Vec3;

const hittable = @import("hittable.zig");
const Sphere = hittable.Sphere;
const HittableList = hittable.HittableList;

const Ray = @import("ray.zig").Ray;
const Camera = @import("camera.zig").Camera;

const Material = @import("material.zig").Material;

const aspect_ratio = 16.0 / 9.0;
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
    const max = @intToFloat(f64, max_color);
    try std.fmt.format(out, "{} {} {}\n", .{
        @floatToInt(u8, math.sqrt(color.x) * max),
        @floatToInt(u8, math.sqrt(color.y) * max),
        @floatToInt(u8, math.sqrt(color.z) * max),
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

const Context = struct {
    idx: usize,
    num_threads: usize,
    world: *const HittableList,
    camera: *const Camera,
    image_width: usize,
    image_height: usize,
    next_pixel: *AtomicInt(usize),
    image: []Vec3,
};

pub fn render(context: Context) void {
    var prng = rand.DefaultPrng.init(context.idx);
    const random = &prng.random;

    const width = context.image_width;
    const height = context.image_height;
    const pixels = width * height;

    var p = context.next_pixel.incr();
    while (p < pixels) : (p = context.next_pixel.incr()) {
        const x = p % width;
        const y = height - 1 - p / width;

        var color = Vec3.zero();
        var s: u32 = 0;
        while (s < samples_per_pixel) : (s += 1) {
            const u = (@intToFloat(f64, x) + random.float(f64)) / @intToFloat(f64, width - 1);
            const v = (@intToFloat(f64, y) + random.float(f64)) / @intToFloat(f64, height - 1);
            const ray = context.camera.getRay(u, v, random);

            // const sample_color = rayNormal(ray, context.world.*);
            // const sample_color = rayAlbedo(ray, context.world.*);
            // const sample_color = rayDepth(ray, max_depth, context.world.*, random);
            const sample_color = rayColor(ray, max_depth, context.world.*, random);

            color.addAssign(sample_color);
        }

        context.image[p] = color.div(@intToFloat(f64, samples_per_pixel));
    }
}

fn printUsageAndExit(binary_name: []const u8) noreturn {
    warn("Usage: {} <width> [<threads>]\n", .{binary_name});
    std.process.exit(1);
}

fn argAsNumber(allocator: *Allocator, args: var) ?anyerror!usize {
    const arg = try args.next(allocator) orelse return null;
    const number = try std.fmt.parseUnsigned(usize, arg, 10);
    if (number == 0) {
        return error.InvalidArgument;
    }

    return number;
}

pub fn main() !void {
    const start = time.milliTimestamp();

    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var args = std.process.args();

    const binary_name = try args.next(allocator) orelse "raytracer";
    const image_width = try argAsNumber(allocator, &args) orelse printUsageAndExit(binary_name);
    const num_threads = try argAsNumber(allocator, &args) orelse try Thread.cpuCount();

    const image_height = @floatToInt(usize, @intToFloat(f64, image_width) / aspect_ratio);
    const pixels = image_width * image_height;

    var buffered_stdout = io.bufferedWriter(io.getStdOut().outStream());
    const stdout_writer = buffered_stdout.writer();

    var prng = rand.DefaultPrng.init(0);
    const random = &prng.random;

    const look_from = Vec3.new(13, 2, 3);
    const look_at = Vec3.new(0, 0, 0);
    const vup = Vec3.new(0, 1, 0);
    const focus_distance = 10.0;
    const aperture = 0.1;
    const fov = 20;

    const camera = Camera.new(look_from, look_at, vup, fov, aspect_ratio, aperture, focus_distance);

    const world = try randomScene(random, allocator);

    const threads = try allocator.alloc(*Thread, num_threads);
    var image = try allocator.alloc(Vec3, pixels);
    var next_pixel = AtomicInt(usize).init(0);

    warn(
        \\Size: {}x{}
        \\Pixels: {}
        \\Samples per pixel: {}
        \\Threads: {}
        \\
    , .{ image_width, image_height, pixels, samples_per_pixel, num_threads });

    for (threads) |*thread, i| {
        const context = Context{
            .idx = i,
            .num_threads = num_threads,
            .world = &world,
            .camera = &camera,
            .image_width = image_width,
            .image_height = image_height,
            .next_pixel = &next_pixel,
            .image = image,
        };

        thread.* = try Thread.spawn(context, render);
    }

    while (true) {
        const current_pixel = next_pixel.get();
        const rendered = if (current_pixel > num_threads) current_pixel - num_threads else 0;
        const percent = @intToFloat(f64, rendered) * 100 / @intToFloat(f64, pixels);

        warn("\r{d:.1}%", .{percent});

        if (rendered == pixels) {
            break;
        }

        std.time.sleep(std.time.ns_per_s);
    }

    for (threads) |thread| {
        thread.wait();
    }

    const elapsed = @intToFloat(f64, std.time.milliTimestamp() - start) / time.ms_per_s;
    warn("\nRendering took {d:.3}s\nWriting image\n", .{elapsed});

    try std.fmt.format(stdout_writer, "P3\n{}\n{}\n{}\n", .{ image_width, image_height, max_color });
    for (image) |color| {
        try writeColor(color, stdout_writer);
    }
    try buffered_stdout.flush();

    warn("Done\n", .{});
}
