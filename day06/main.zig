const std = @import("std");

fn solve(t: usize, m: u64) u32 {
    var count: u32 = 0;
    for (0..t) |i| {
        if (i * (t - i) > m) {
            count = count + 1;
        }
    }
    return count;
}

pub fn main() !void {
    const input: [4][2]usize = [4][2]usize{ [2]usize{ 35, 213 }, [2]usize{ 69, 1168 }, [2]usize{ 68, 1086 }, [2]usize{ 87, 1248 } };
    var product: u32 = 1;
    for (input) |entry| {
        product *= solve(entry[0], @as(u64, entry[1]));
    }
    std.debug.print("Part1 - {d}\n", .{product});
    std.debug.print("Part2 - {d}\n", .{solve(35696887, 213116810861248)});
}
