const std = @import("std");
const math = std.math;
const Random = std.rand.Random;

pub const Vec3 = struct {
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

    pub fn one() Vec3 {
        return Vec3.new(1, 1, 1);
    }

    pub fn randomRange(random: *Random, min: f64, max: f64) Vec3 {
        return Vec3.new(
            randomf64Range(random, min, max),
            randomf64Range(random, min, max),
            randomf64Range(random, min, max),
        );
    }

    pub fn randomInUnitSphere(random: *Random) Vec3 {
        while (true) {
            const p = Vec3.randomRange(random, -1, 1);
            if (p.lengthSquared() < 1) {
                return p;
            }
        }
    }

    pub fn randomUnitVector(random: *Random) Vec3 {
        const a = randomf64Range(random, 0, 2 * math.pi);
        const z = randomf64Range(random, -1, 1);
        const r = math.sqrt(1 - z * z);
        return Vec3.new(r * math.cos(a), r * math.sin(a), z);
    }

    pub fn randomInHemisphere(random: *Random, normal: Vec3) Vec3 {
        const in_unit_sphere = randomInUnitSphere(random);
        return if (in_unit_sphere.dot(normal) > 0) in_unit_sphere else in_unit_sphere.mul(-1);
    }

    pub fn randomInUnitDisk(random: *Random) Vec3 {
        while (true) {
            const p = Vec3.new(randomf64Range(random, -1, 1), randomf64Range(random, -1, 1), 0);
            if (p.lengthSquared() < 1) {
                return p;
            }
        }
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

    pub fn mulVec(self: Vec3, other: Vec3) Vec3 {
        return Vec3.new(self.x * other.x, self.y * other.y, self.z * other.z);
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

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3.new(
            self.y * other.z - self.z * other.y,
            self.z * other.x - self.x * other.z,
            self.x * other.y - self.y * other.x,
        );
    }
};

fn randomf64Range(random: *Random, min: f64, max: f64) f64 {
    return min + (max - min) * random.float(f64);
}
