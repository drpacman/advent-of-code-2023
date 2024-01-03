const std = @import("std");

const Line = struct {
    a: f128,
    c: f128,
    pos: [3]f128,
    deltas: [3]f128,

    fn intersection(self: Line, other: Line) ?[2]f128 {
        if (self.a == other.a) return null;
        const x = (other.c - self.c) / (self.a - other.a);
        const y = self.a * x + self.c;
        return [2]f128{ x, y };
    }

    fn is_future_intersection(self: Line, pos: [2]f128) bool {
        if (self.pos[0] < pos[0] and self.deltas[0] < 0) return false;
        if (self.pos[0] > pos[0] and self.deltas[0] > 0) return false;
        if (self.pos[1] < pos[1] and self.deltas[1] < 0) return false;
        if (self.pos[1] > pos[1] and self.deltas[1] > 0) return false;
        return true;
    }
};

fn parse_number(elem: []const u8) !f128 {
    return std.fmt.parseFloat(f128, std.mem.trim(u8, elem, " "));
}

fn parse(path: []const u8, allocator: std.mem.Allocator) ![]Line {
    var results = std.ArrayList(Line).init(allocator);
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var file_lines = std.mem.split(u8, file_contents, "\n");
    while (file_lines.next()) |line| {
        var elems = std.mem.splitAny(u8, line, ",@");
        const x = try parse_number(elems.next().?);
        const y = try parse_number(elems.next().?);
        const z = try parse_number(elems.next().?);
        const dx = try parse_number(elems.next().?);
        const dy = try parse_number(elems.next().?);
        const dz = try parse_number(elems.next().?);
        const grad = dy / dx;
        try results.append(Line{ .a = grad, .c = y - (grad) * x, .pos = [3]f128{ x, y, z }, .deltas = [3]f128{ dx, dy, dz } });
    }
    return results.toOwnedSlice();
}

fn part1(lines: []Line, min: f128, max: f128) !u64 {
    var total: u64 = 0;
    for (0..lines.len) |i| {
        for (i + 1..lines.len) |j| {
            const intersection = lines[i].intersection(lines[j]);
            if (intersection) |ins| {
                if (ins[0] < min or ins[0] > max or ins[1] < min or ins[1] > max) continue;
                // is intersection in the future?
                if (!lines[i].is_future_intersection(ins)) continue;
                if (!lines[j].is_future_intersection(ins)) continue;
                total += 1;
            }
        }
    }
    return total;
}

// Uses Cramers rule to solve set of equations:
// See https://ua.pressbooks.pub/collegealgebraformanagerialscience/chapter/3-5-determinants-and-cramers-rule
// where a1x + b1y = c1
// and   a2x + b2y = c2
// x = Dx/D
// y = Dy/D
// D = determinant
// | a1 b1 |
// | a2 b2 |
// Dx = determinant with constants replacing x column
// | c1 b1 |
// | c2 b2 |
// Dy = determinant with constants replacing y column
// | a1 c1 |
// | a2 c2 |
fn part2(l: []Line) f128 {
    // zig fmt: off
    const c = [4]f128{ l[0].pos[0] * l[0].deltas[1] - l[1].pos[0] * l[1].deltas[1] + l[1].pos[1] * l[1].deltas[0] - l[0].pos[1] * l[0].deltas[0], 
                      l[2].pos[0] * l[2].deltas[1] - l[3].pos[0] * l[3].deltas[1] + l[3].pos[1] * l[3].deltas[0] - l[2].pos[1] * l[2].deltas[0], 
                      l[4].pos[0] * l[4].deltas[1] - l[5].pos[0] * l[5].deltas[1] + l[5].pos[1] * l[5].deltas[0] - l[4].pos[1] * l[4].deltas[0], 
                      l[6].pos[0] * l[6].deltas[1] - l[7].pos[0] * l[7].deltas[1] + l[7].pos[1] * l[7].deltas[0] - l[6].pos[1] * l[6].deltas[0] };
    const M = [4][4]f128{ [4]f128{ l[0].pos[0] - l[1].pos[0], l[1].pos[1] - l[0].pos[1], l[1].deltas[0] - l[0].deltas[0], l[0].deltas[1] - l[1].deltas[1] },
                          [4]f128{ l[2].pos[0] - l[3].pos[0], l[3].pos[1] - l[2].pos[1], l[3].deltas[0] - l[2].deltas[0], l[2].deltas[1] - l[3].deltas[1] },
                          [4]f128{ l[4].pos[0] - l[5].pos[0], l[5].pos[1] - l[4].pos[1], l[5].deltas[0] - l[4].deltas[0], l[4].deltas[1] - l[5].deltas[1] },
                          [4]f128{ l[6].pos[0] - l[7].pos[0], l[7].pos[1] - l[6].pos[1], l[7].deltas[0] - l[6].deltas[0], l[6].deltas[1] - l[7].deltas[1] }};
    const D = det4x4(M);
    // vars are DRY, DRX, PRY, PRX in that order
    const DRY = det4x4([4][4]f128{ [4]f128{ c[0], M[0][1], M[0][2], M[0][3] },
                                   [4]f128{ c[1], M[1][1], M[1][2], M[1][3] },
                       [4]f128{ c[2], M[2][1], M[2][2], M[2][3] },
                       [4]f128{ c[3], M[3][1], M[3][2], M[3][3] }})/D;
    const DRX = det4x4([4][4]f128{  [4]f128{ M[0][0], c[0], M[0][2], M[0][3] },
                                    [4]f128{ M[1][0], c[1], M[1][2], M[1][3] },
                                    [4]f128{ M[2][0], c[2], M[2][2], M[2][3] },
                                    [4]f128{ M[3][0], c[3], M[3][2], M[3][3] }})/D;
    const PRY = det4x4([4][4]f128{  [4]f128{ M[0][0], M[0][1], c[0], M[0][3] },
                                    [4]f128{ M[1][0], M[1][1], c[1], M[1][3] },
                                    [4]f128{ M[2][0], M[2][1], c[2], M[2][3] },
                                    [4]f128{ M[3][0], M[3][1], c[3], M[3][3] }})/D;
    const PRX = det4x4([4][4]f128{  [4]f128{ M[0][0], M[0][1], M[0][2], c[0] },
                                    [4]f128{ M[1][0], M[1][1], M[1][2], c[1] },
                                    [4]f128{ M[2][0], M[2][1], M[2][2], c[2] },
                                    [4]f128{ M[3][0], M[3][1], M[3][2], c[3] }})/D;
    // now solve the time values for the first 2 hailstones
    const t0 : f128 = (l[0].pos[0] - PRX)/(DRX - l[0].deltas[0]);
    const t1 : f128  = (l[1].pos[1] - PRY)/(DRY - l[1].deltas[1]);
    // substitute for t0 and t1 to get DRZ
    const DRZ : f128 = (t1*l[1].deltas[2] - t0 * l[0].deltas[2] + l[1].pos[2] - l[0].pos[2]) / (t1-t0);
    // find PRZ
    const PRZ : f128 = t0*(l[0].deltas[2] - DRZ) + l[0].pos[2];        
    
    return PRX + PRY + PRZ;
    // zig fmt: on

}
// Determinants - see https://quickmath.com/webMathematica3/quickmath/matrices/determinant/basic.jsp
// Determinant of a 2x2 matrix is product of diagonal elements minus product of off-diagonal elements
fn det2x2(m: [2][2]f128) f128 {
    return m[0][0] * m[1][1] - m[0][1] * m[1][0];
}

// Determinant of a 3x3 matrix is sum of product of each elemenbt in col1 with determinant of 2x2 matrix formed by removing row and col of that element
fn det3x3(m: [3][3]f128) f128 {
    const a = m[0][0];
    const b = m[1][0];
    const c = m[2][0];
    // zig fmt: off
    return a * det2x2([2][2]f128{ m[1][1..3].*, m[2][1..3].* }) 
         - b * det2x2([2][2]f128{ m[0][1..3].*, m[2][1..3].* }) 
         + c * det2x2([2][2]f128{ m[0][1..3].*, m[1][1..3].* });
    // zig fmt: on
}

// Determinant of a 4x4 matrix is sum of product of each elemenbt in col1 with determinant of 3x3 matrix formed by removing row and col of that element
fn det4x4(m: [4][4]f128) f128 {
    const a = m[0][0];
    const b = m[1][0];
    const c = m[2][0];
    const d = m[3][0];
    // zig fmt: off
    return a * det3x3([3][3]f128{ m[1][1..4].*, m[2][1..4].*, m[3][1..4].* }) 
         - b * det3x3([3][3]f128{ m[0][1..4].*, m[2][1..4].*, m[3][1..4].* }) 
         + c * det3x3([3][3]f128{ m[0][1..4].*, m[1][1..4].*, m[3][1..4].* }) 
         - d * det3x3([3][3]f128{ m[0][1..4].*, m[1][1..4].*, m[2][1..4].* });
    // zig fmt: on
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const lines = try parse("day24/input.txt", allocator);
    std.debug.print("Part 1: {d}\n", .{try part1(lines, 200000000000000, 400000000000000)});
    std.debug.print("Part 2: {d}\n", .{@as(f64, @floatCast(part2(lines)))});
}

test "det3x3" {
    const m = [3][3]f128{ [3]f128{ 1, 2, 3 }, [3]f128{ 4, 5, 6 }, [3]f128{ 7, 8, 9 } };
    const d = det3x3(m);
    std.debug.assert(d == 0);
}

test "det4x4" {
    const m = [4][4]f128{ [4]f128{ 4, 3, 2, 2 }, [4]f128{ 0, 1, -3, 3 }, [4]f128{ 0, -1, 3, 3 }, [4]f128{ 0, 3, 1, 1 } };
    const d = det4x4(m);
    std.debug.assert(d == -240);
}
