const std = @import("std");

const Brick = struct {
    x1: u16,
    x2: u16,
    y1: u16,
    y2: u16,
    z1: u16,
    z2: u16,

    fn less_then(_: void, self: Brick, other: Brick) bool {
        if (other.z1 < self.z1) return false;
        if (other.z1 > self.z1) return true;

        if (other.z2 < self.z2) return false;
        if (other.z2 > self.z2) return true;

        if (other.y1 < self.y1) return false;
        if (other.y1 > self.y1) return true;

        if (other.y2 < self.y2) return false;
        if (other.y2 > self.y2) return true;

        if (other.x1 < self.x1) return false;
        if (other.x1 > self.x1) return true;

        if (other.x2 < self.x2) return false;
        if (other.x2 > self.x2) return true;

        return true;
    }

    fn supports(self: Brick, other: Brick) bool {
        return self.z2 + 1 == other.z1 and blocks(self, other);
    }

    fn blocks(self: Brick, other: Brick) bool {
        return ((self.x1 >= other.x1 and self.x1 <= other.x2) or (self.x1 <= other.x1 and self.x2 >= other.x1)) and
            ((self.y1 >= other.y1 and self.y1 <= other.y2) or (self.y1 <= other.y1 and self.y2 >= other.y1));
    }
};

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![]Brick {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines_iter = std.mem.splitAny(u8, file_contents, "\n");
    var bricks = std.ArrayList(Brick).init(allocator);
    const parseInt = std.fmt.parseInt;
    while (lines_iter.next()) |line| {
        var parts = std.mem.splitAny(u8, line, "~,");
        const x1 = try parseInt(u16, parts.next().?, 10);
        const y1 = try parseInt(u16, parts.next().?, 10);
        const z1 = try parseInt(u16, parts.next().?, 10);
        const x2 = try parseInt(u16, parts.next().?, 10);
        const y2 = try parseInt(u16, parts.next().?, 10);
        const z2 = try parseInt(u16, parts.next().?, 10);

        try bricks.append(Brick{ .x1 = x1, .x2 = x2, .y1 = y1, .y2 = y2, .z1 = z1, .z2 = z2 });
    }
    return bricks.toOwnedSlice();
}

fn part1(bricks: []Brick, allocator: std.mem.Allocator) !u64 {
    // sort the bricks
    std.sort.insertion(Brick, bricks, {}, Brick.less_then);
    var done = false;
    while (!done) {
        done = true;
        drop_bricks: for (bricks, 0..) |brick, index| {
            if (brick.z1 == 1) continue;
            // check prior bricks to see if any already support this brick
            for (0..index) |i| {
                if (bricks[i].supports(brick)) continue :drop_bricks;
            }
            done = false;
            bricks[index] = Brick{ .x1 = brick.x1, .y1 = brick.y1, .z1 = brick.z1 - 1, .x2 = brick.x2, .y2 = brick.y2, .z2 = brick.z2 - 1 };
        }
    }

    // walk bricks and identify any bricks which are the not the only supporting brick
    // First create set of total possible removable bricks
    var removable_bricks = std.AutoHashMap(Brick, void).init(allocator);
    for (bricks) |brick| {
        try removable_bricks.put(brick, {});
    }
    supported_bricks_loop: for (bricks) |brick| {
        if (brick.z1 == 1) continue;
        var single_supporting_brick: ?Brick = null;
        for (bricks) |other_brick| {
            if (other_brick.supports(brick)) {
                if (single_supporting_brick) |_| {
                    // multiple supporting bricks found, move onto the next brick
                    continue :supported_bricks_loop;
                } else {
                    single_supporting_brick = other_brick;
                }
            }
        }
        if (single_supporting_brick) |supporting_brick| {
            _ = removable_bricks.remove(supporting_brick);
        }
    }
    return removable_bricks.count();
}

fn part2(bricks: []Brick, allocator: std.mem.Allocator) !u64 {
    // sort the bricks
    std.sort.insertion(Brick, bricks, {}, Brick.less_then);

    var total: u64 = 0;
    for (0..bricks.len) |i| {
        // copy the bricks, removing one brick
        var bricks_copy = try allocator.alloc(*Brick, bricks.len - 1);
        var n: usize = 0;
        while (n < bricks.len - 1) {
            if (n < i) {
                bricks_copy[n] = &bricks[n];
            } else if (n >= i) {
                bricks_copy[n] = &bricks[n + 1];
            }
            n += 1;
        }
        var dropped_count: u32 = 0;
        // drop all bricks which are not supported and count them
        drop_bricks: for (bricks_copy, 0..) |brick, index| {
            if (brick.*.z1 == 1) continue;
            // check prior bricks to see if any already support this brick
            for (0..index) |j| {
                if (bricks_copy[j].*.supports(brick.*)) continue :drop_bricks;
            }

            bricks_copy[index] = try allocator.create(Brick);
            bricks_copy[index].* = .{ .x1 = brick.*.x1, .y1 = brick.*.y1, .z1 = brick.*.z1 - 1, .x2 = brick.*.x2, .y2 = brick.*.y2, .z2 = brick.*.z2 - 1 };
            dropped_count += 1;
        }
        total += dropped_count;
    }
    return total;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bricks = try parse_file("day22/input.txt", allocator);
    std.debug.print("Part 1: {}\n", .{try part1(bricks, allocator)});
    std.debug.print("Part 2: {}\n", .{try part2(bricks, allocator)});
}
