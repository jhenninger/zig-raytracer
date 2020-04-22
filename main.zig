const std = @import("std");
const math = std.math;
const io = std.io;
const mem = std.mem;
const rand = std.rand;
const ArrayList = std.ArrayList;

const factor = 2;

const imageWidth = 200 * factor;
const imageHeight = 100 * factor;
const maxColor = 255;
const samplesPerPixel = 100;

const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn new(x: f64, y: f64, z: f64) Vec3 {
        return Vec3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn zero() Vec3 {
        return Vec3.new(0, 0, 0);
    }

    pub fn neg(self: Vec3) Vec3 {
        return self.mul(-1);
    }

    pub fn dot(self: Vec3, other: Vec3) f64 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3.new(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub fn addAssign(self: *Vec3, other: Vec3) void {
        self.x += other.x;
        self.y += other.y;
        self.z += other.z;
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3.new(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub fn mul(self: Vec3, scalar: f64) Vec3 {
        return Vec3.new(self.x * scalar, self.y * scalar, self.z * scalar);
    }

    pub fn div(self: Vec3, scalar: f64) Vec3 {
        return self.mul(1 / scalar);
    }

    pub fn length(self: Vec3) f64 {
        return math.sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: Vec3) f64 {
        return self.dot(self);
    }

    pub fn unit(self: Vec3) Vec3 {
        return self.div(self.length());
    }

    pub fn write(self: Vec3, out: var) !void {
        const r = self.x / samplesPerPixel;
        const g = self.y / samplesPerPixel;
        const b = self.z / samplesPerPixel;

        try out.print("{} {} {}\n", .{
            @floatToInt(u8, r * maxColor),
            @floatToInt(u8, g * maxColor),
            @floatToInt(u8, b * maxColor),
        });
    }
};

const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn new(origin: Vec3, direction: Vec3) Ray {
        return Ray{
            .origin = origin,
            .direction = direction,
        };
    }

    pub fn at(self: Ray, t: f64) Vec3 {
        return self.origin.add(self.direction.mul(t));
    }
};

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

const Sphere = struct {
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

const HittableList = struct {
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

fn rayColor(ray: Ray, hittable: HittableList) Vec3 {
    if (hittable.hit(ray, 0, math.inf(f64))) |hit| {
        return hit.normal.add(Vec3.new(1, 1, 1)).mul(0.5);
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

    const camera = Camera.new();

    const spheres = &[_]Sphere{
        Sphere.new(Vec3.new(0, 0, -1), 0.5),
        Sphere.new(Vec3.new(0, -100.5, -1), 100),
    };

    const world = HittableList{ .objects = spheres };

    var buf: [8]u8 = undefined;
    try std.crypto.randomBytes(buf[0..]);
    const seed = mem.readIntLittle(u64, buf[0..8]);
    var r = rand.DefaultPrng.init(seed);

    var y: i32 = imageHeight;
    while (y >= 0) : (y -= 1) {
        try stderr.print("\rScanlines remaining: {: >3}", .{@intCast(u32, y)});
        var x: i32 = 0;
        while (x < imageWidth) : (x += 1) {
            var color = Vec3.zero();
            var s: i32 = 0;
            while (s < samplesPerPixel) : (s += 1) {
                const u = (@intToFloat(f64, x) + r.random.float(f64)) / imageWidth;
                const v = (@intToFloat(f64, y) + r.random.float(f64)) / imageHeight;
                const ray = camera.getRay(u, v);
                color.addAssign(rayColor(ray, world));
            }
            try color.write(stdout);
        }
    }
}
