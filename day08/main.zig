const std = @import("std");

const Node = struct { id: []const u8, left: []const u8, right: []const u8 };
const Maze = struct { directions: []const u8, nodes: []Node };
fn parse_file(path: []const u8, allocator: std.mem.Allocator) !Maze {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines_iter = std.mem.split(u8, content, "\n");
    const directions: []const u8 = lines_iter.next().?;
    _ = lines_iter.next();
    var nodes = std.ArrayList(Node).init(allocator);
    while (lines_iter.next()) |line| {
        try nodes.append(Node{ .id = line[0..3], .left = line[7..10], .right = line[12..15] });
    }
    return Maze{ .nodes = try nodes.toOwnedSlice(), .directions = directions };
}

fn part1(maze: Maze) u32 {
    var i: u64 = 0;
    var count: u32 = 0;
    var curr: []const u8 = "AAA";
    while (!std.mem.eql(u8, "ZZZ", curr)) : (i = (i + 1) % maze.directions.len) {
        for (maze.nodes) |node| {
            if (!std.mem.eql(u8, node.id, curr)) continue;
            curr = if (maze.directions[i] == 'L') node.left else node.right;
            break;
        }
        count += 1;
    }
    return count;
}

const CycleMarker = struct { start_id: []const u8, current: []const u8, instruction_loop: u64 };

fn lcm(first: u64, second: u64) u64 {
    var a: u64 = first;
    var b: u64 = second;
    var result: u64 = 1;
    var i: u64 = 2;
    while (a != 1 or b != 1) {
        if (a % i == 0 or b % i == 0) {
            result *= i;
            if (a % i == 0) a /= i;
            if (b % i == 0) b /= i;
        } else {
            i += 1;
        }
    }
    return result;
}

fn part2(maze: Maze, allocator: std.mem.Allocator) !u64 {
    var i: u64 = 0;
    var count: u64 = 0;
    var start_nodes = std.ArrayList(CycleMarker).init(allocator);
    var done: bool = false;

    for (maze.nodes) |node| {
        if (node.id[2] == 'A') try start_nodes.append(CycleMarker{ .start_id = node.id, .current = node.id, .instruction_loop = 0 });
    }

    const markers: []CycleMarker = try start_nodes.toOwnedSlice();
    var loop_count: u64 = 0;
    while (!done) : (i = (i + 1) % maze.directions.len) {
        for (markers) |*marker| {
            if (marker.*.current[2] == 'Z') {
                marker.*.instruction_loop = loop_count;
                std.debug.print("Found loop for {s} - {d}\n", .{ marker.*.start_id, marker.*.instruction_loop });
            }
        }

        done = true;
        for (markers) |marker| {
            if (marker.instruction_loop == 0) {
                done = false;
            }
        }

        if (!done) {
            // update all items
            for (markers) |*marker| {
                for (maze.nodes) |node| {
                    if (!std.mem.eql(u8, node.id, marker.*.current)) continue;
                    marker.*.current = if (maze.directions[i] == 'L') node.left else node.right;
                    break;
                }
            }
            count += 1;
        }
        loop_count += 1;
    }

    var lcm_result: u64 = 1;
    for (markers) |marker| {
        if (lcm_result == 1) {
            lcm_result = marker.instruction_loop;
        } else {
            lcm_result = lcm(lcm_result, marker.instruction_loop);
        }
    }
    return lcm_result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var maze = try parse_file("day08/test.txt", allocator);
    std.debug.print("Part1 - {}\n", .{part1(maze)});
    maze = try parse_file("day08/input.txt", allocator);
    std.debug.print("Part2 - {d}\n", .{try part2(maze, allocator)});
}

test "part1" {
    const allocator = std.heap.page_allocator;
    const maze = try parse_file("day08/test.txt", allocator);
    try std.testing.expectEqual(part1(maze), 6);
}

test "part2" {
    const allocator = std.heap.page_allocator;
    const maze = try parse_file("day08/test2.txt", allocator);
    try std.testing.expectEqual(try part2(maze, allocator), 6);
}
