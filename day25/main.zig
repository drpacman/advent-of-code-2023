const std = @import("std");

const Set = std.StringHashMap(void);

fn parse_file(path: []const u8, allocator: std.mem.Allocator) !std.StringHashMap(*Set) {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var nodes = std.StringHashMap(*Set).init(allocator);
    var lines_iter = std.mem.split(u8, file_contents, "\n");
    while (lines_iter.next()) |line| {
        const name = line[0..3];
        var set = nodes.get(name);
        if (set == null) {
            const node_set = try allocator.create(Set);
            node_set.* = Set.init(allocator);
            try nodes.put(name, node_set);
            set = node_set;
        }
        var i: u8 = 5;
        while (i < line.len) : (i += 4) {
            const child_name = line[i .. i + 3];
            var connected_node_set = nodes.get(child_name);
            if (connected_node_set == null) {
                const connected_set = try allocator.create(Set);
                connected_set.* = Set.init(allocator);
                try nodes.put(child_name, connected_set);
                connected_node_set = connected_set;
            }
            try connected_node_set.?.put(name, {});
            try set.?.put(child_name, {});
        }
    }

    return nodes;
}

// count the number of connections from a named node to nodes not in the provided set
fn cross_set_connection_count(name: []const u8, nodes: *std.StringHashMap(*Set), set: *Set) u8 {
    var count: u8 = 0;
    var connected_node_names = nodes.get(name).?.keyIterator();
    while (connected_node_names.next()) |connected_node_name| {
        if (!set.*.contains(connected_node_name.*)) {
            count += 1;
        }
    }
    return count;
}

fn most_connected_node(nodes: *std.StringHashMap(*Set), set: *Set) []const u8 {
    var most_connected_node_name: ?[]const u8 = null;
    var most_connected_node_count: ?u8 = null;
    var set_node_names = set.keyIterator();
    while (set_node_names.next()) |set_node_name| {
        const count = cross_set_connection_count(set_node_name.*, nodes, set);
        if (most_connected_node_count == null or count > most_connected_node_count.?) {
            most_connected_node_name = set_node_name.*;
            most_connected_node_count = count;
        }
    }
    return most_connected_node_name.?;
}

fn part1(nodes: *std.StringHashMap(*Set)) !usize {
    var set = Set.init(std.heap.page_allocator);
    var names = nodes.keyIterator();
    while (names.next()) |name| {
        try set.put(name.*, {});
    }

    var count: u32 = 0;
    while (count != 3) {
        const most_connected_node_name = most_connected_node(nodes, &set);
        _ = set.remove(most_connected_node_name);

        // count the number of connections from the set to the rest
        count = 0;
        var remaining_keys = set.keyIterator();
        while (remaining_keys.next()) |node_name| {
            count += cross_set_connection_count(node_name.*, nodes, &set);
        }
    }

    const partition_A_size = set.count();
    const partition_B_size = nodes.count() - partition_A_size;
    return partition_A_size * partition_B_size;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var nodes = try parse_file("day25/input.txt", allocator);
    std.debug.print("Part 1 - {d}\n", .{try part1(&nodes)});
}
