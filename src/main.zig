const std = @import("std");
const wood = @import("wood");

/// HyperLogLog is a probabilistic datastructure to get the approximate count of the number of distinct elements
const HyperLogLog = struct {
    /// Precision of the count, from 1 to 10.
    precision: usize,

    /// Allocator for any dynamic memory needs.
    alloc: std.mem.Allocator,

    /// Number of buckets, derived from precision.
    num_buckets: u32,

    ///Buckets to keep the hasheld values.
    buckets: []u8,

    const Self = @This();

    /// Initialise HLL object with precision P. For every p the memory used will be 2^p
    pub fn new(alloc: std.mem.Allocator, p: u32) Self {
        // Assert if the precision is in the valid range.
        std.debug.assert(p >= 4 and p <= 16);

        // Get the number of buckets from the precision. gives 2^p
        const num_buckets: u32 = @as(u32, 1) << @intCast(p);

        const bucketList = alloc.alloc(u8, num_buckets) catch {
            std.debug.panic("downloadmoreram.com", .{});
        };

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

    pub fn add(self: *Self, comptime T: type, value: T) void {
        const bytes: []const u8 = std.mem.asBytes(&value);
        const hash_value = hash(bytes);

        const bucket_index: usize = @intCast(hash_value & (self.num_buckets - 1));

        // The first p bits are used to determine the bucket, the remaining bits are used to determine the value to store in the bucket.
        const remaining_value = hash_value >> @intCast(self.precision);
        const lz = leading_zeroes(remaining_value) + 1;

        if (lz > self.buckets[bucket_index]) {
            self.buckets[bucket_index] = lz;
        }
    }

    pub fn count(self: *Self) f64 {
        return 0.0;
    }

    pub fn leading_zeroes(value: u128) u8 {
        return 0;
    }

    pub fn hash(value: []const u8) u128 {
        var hasher = std.hash.SipHash128(1, 2).init(&[_]u8{0} ** 16);
        hasher.update(value);
        return hasher.finalInt();
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var hll = HyperLogLog.new(allocator, 10);
    defer hll.deinit();
    const N: u32 = 1000000;
    for (0..N) |i_usize| {
        const i: u32 = @intCast(i_usize);
        hll.add(u32, i);
    }
    const estimate = hll.count();
    std.debug.print("Estimated distinct count: {}\n", .{estimate});
    std.debug.print("Actual distinct count: {}\n", .{N});
}
