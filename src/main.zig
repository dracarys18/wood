const std = @import("std");
const wood = @import("wood");

/// HyperLogLog is a probabilistic data structure for estimating the cardinality of a multiset.
///
/// Well let's suppose you have a number 10110, the probability that the first bit would be 0 is 50%, and the
/// probability that the first two bits would be 00 is 25% so the probability that the first n bits would be 0 is 1/(2^n).
///
/// Hyperloglog uses this exact method to get the cadinality of a multiset.
const HyperLogLog = struct {
    precision: u8,
    alloc: std.mem.Allocator,
    num_buckets: u32,
    buckets: []u8,

    const Self = @This();

    /// Creates a new Hyperloglog object with precision `p`, `p` should be within 4 and 16
    pub fn new(alloc: std.mem.Allocator, p: u8) !Self {
        std.debug.assert(p >= 4 and p <= 16);

        const num_buckets: u32 = @as(u32, 1) << @intCast(p);

        const bucketList = try alloc.alloc(u8, num_buckets);
        @memset(bucketList, 0);

        return Self{
            .precision = p,
            .alloc = alloc,
            .num_buckets = num_buckets,
            .buckets = bucketList,
        };
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.buckets);
    }

    /// Adds a value to the HyperLogLog, the value can be of any type that can be converted to bytes
    ///
    /// The way this works is that we hash the value to get a uniformly distributed 128-bit integer, then we use the first `p` bits to determine which bucket to use, and the remaining bits to determine the position of the leftmost 1-bit.
    pub fn add(self: *Self, comptime T: type, value: T) void {
        const bytes: []const u8 = std.mem.asBytes(&value);
        const hash_value = hash(bytes);

        const bucket_index: usize = @intCast(hash_value & (self.num_buckets - 1));

        // shift off p bits
        const remaining_value = hash_value >> @intCast(self.precision);

        const lz = rho(remaining_value, 128 - self.precision);

        if (lz > self.buckets[bucket_index]) {
            self.buckets[bucket_index] = lz;
        }
    }

    /// Count estimates the cardinality of the multiset
    ///
    /// This implementation uses the raw HyperLogLog algorithm with bias correction for small cardinalities.
    /// For very large cardinalities, further corrections may be needed, but this implementation does not include them.
    pub fn count(self: *Self) f64 {
        const m: f64 = @floatFromInt(self.buckets.len);
        const alpha_m: f64 = switch (self.buckets.len) {
            16 => 0.673,
            32 => 0.697,
            64 => 0.709,
            else => 0.7213 / (1.0 + 1.079 / m),
        };

        var sum: f64 = 0.0;
        for (self.buckets) |r| {
            sum += std.math.pow(f64, 2.0, -@as(f64, @floatFromInt(r)));
        }

        var estimate: f64 = alpha_m * m * m / sum;

        var zeroCount: usize = 0;
        for (self.buckets) |r| {
            if (r == 0) zeroCount += 1;
        }

        if (estimate <= 2.5 * m and zeroCount > 0) {
            estimate = m * std.math.log(f64, std.math.e, m / @as(f64, @floatFromInt(zeroCount)));
        }

        return estimate;
    }

    /// rho finds position of leftmost 1-bit in `value`
    fn rho(value: u128, max_bits: u8) u8 {
        if (value == 0) return max_bits + 1;
        return @intCast(@clz(value) + 1);
    }

    fn hash(value: []const u8) u128 {
        var hasher = std.hash.SipHash128(1, 2).init(&[_]u8{0} ** 16);
        hasher.update(value);
        return hasher.finalInt();
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var hll = try HyperLogLog.new(allocator, 10);
    defer hll.deinit();
    const N: u32 = 1000000000;
    for (0..N) |i_usize| {
        const i: u32 = @intCast(i_usize);
        hll.add(u32, i);
    }
    const estimate = hll.count();
    std.debug.print("Estimated distinct count: {}\n", .{estimate});
    std.debug.print("Actual distinct count: {}\n", .{N});
}
