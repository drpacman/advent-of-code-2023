const std = @import("std");

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};

const Step = struct {
    direction: Direction,
    pos: [2]u16,
    prev: ?*const Step,
    len: u32,

    fn contains(self: Step, other: Step) bool {
        if (self.pos[0] == other.pos[0] and self.pos[1] == other.pos[1]) {
            return true;
        } else if (self.prev) |p| {
            return p.contains(other);
        }
        return false;
    }
};

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.ArrayList([]const u8).init(allocator);
    var lines_iter = std.mem.split(u8, file_contents, "\n");
    while (lines_iter.next()) |line| {
        try lines.append(line);
    }
    return lines.toOwnedSlice();
}

fn walk(grid: [][]const u8, allocator: std.mem.Allocator, no_slopes: bool) ![]Step {
    const start = try allocator.create(Step);
    start.* = .{ .direction = Direction.Down, .pos = [2]u16{ 0, 1 }, .prev = null, .len = 0 };

    var walks = std.ArrayList(*Step).init(allocator);
    try walks.append(start);
    var completed_paths = std.ArrayList(Step).init(allocator);
    walks: while (walks.items.len > 0) {
        const current_step = walks.pop();
        const y = current_step.pos[0];
        const x = current_step.pos[1];
        // found the exit
        if (y == grid.len - 1 and x == grid[y].len - 2) {
            try completed_paths.append(current_step.*);
            continue :walks;
        }

        var dirs = std.ArrayList(Direction).init(allocator);
        defer dirs.deinit();
        if (no_slopes and grid[y][x] == '>') {
            try dirs.append(Direction.Right);
        } else if (no_slopes and grid[y][x] == '<') {
            try dirs.append(Direction.Left);
        } else if (no_slopes and grid[y][x] == '^') {
            try dirs.append(Direction.Up);
        } else if (no_slopes and grid[y][x] == 'v') {
            try dirs.append(Direction.Down);
        } else {
            if (current_step.direction != Direction.Down) try dirs.append(Direction.Up);
            if (current_step.direction != Direction.Up) try dirs.append(Direction.Down);
            if (current_step.direction != Direction.Right) try dirs.append(Direction.Left);
            if (current_step.direction != Direction.Left) try dirs.append(Direction.Right);
        }
        const ds = try dirs.toOwnedSlice();
        for (ds) |dir| {
            const next_step = try allocator.create(Step);
            if (dir == Direction.Left and x > 1 and grid[y][x - 1] != '#') {
                next_step.* = .{ .direction = Direction.Left, .pos = [2]u16{ y, x - 1 }, .prev = current_step, .len = current_step.len + 1 };
            } else if (dir == Direction.Right and x < grid[0].len - 2 and grid[y][x + 1] != '#') {
                next_step.* = .{ .direction = Direction.Right, .pos = [2]u16{ y, x + 1 }, .prev = current_step, .len = current_step.len + 1 };
            } else if (dir == Direction.Down and y < grid.len - 1 and grid[y + 1][x] != '#') {
                next_step.* = .{ .direction = Direction.Down, .pos = [2]u16{ y + 1, x }, .prev = current_step, .len = current_step.len + 1 };
            } else if (dir == Direction.Up and y > 1 and grid[y - 1][x] != '#') {
                next_step.* = .{ .direction = Direction.Up, .pos = [2]u16{ y - 1, x }, .prev = current_step, .len = current_step.len + 1 };
            } else {
                continue;
            }

            if (!current_step.contains(next_step.*)) {
                try walks.append(next_step);
            }
        }
    }
    return completed_paths.toOwnedSlice();
}

// every junction is a node
const Node = struct {
    pos: [2]u16,
    edges: []Edge,

    fn equals(self: Node, other: Node) bool {
        return (self.pos[0] == other.pos[0] and self.pos[1] == other.pos[1]);
    }
};
const Edge = struct { len: u32, start_node: *const Node, end_node: *const Node };
const Graph = struct { nodes: []*Node, start_node: *const Node, end_node: *const Node };
const NodePath = struct {
    node: *const Node,
    prev: ?*const NodePath,
    len: u32,

    fn contains(self: NodePath, other: Node) bool {
        if (self.node.*.equals(other)) {
            return true;
        } else if (self.prev) |p| {
            return p.contains(other);
        }
        return false;
    }
};

fn get_moves(grid: [][]const u8, x: u16, y: u16, allocator: std.mem.Allocator) ![][2]u16 {
    var moves = std.ArrayList([2]u16).init(allocator);
    if (x > 0 and grid[y][x - 1] != '#') {
        try moves.append([2]u16{ y, x - 1 });
    }
    if (x < grid[0].len - 1 and grid[y][x + 1] != '#') {
        try moves.append([2]u16{ y, x + 1 });
    }
    if (y > 1 and grid[y - 1][x] != '#') {
        try moves.append([2]u16{ y - 1, x });
    }
    if (y < grid.len - 1 and grid[y + 1][x] != '#') {
        try moves.append([2]u16{ y + 1, x });
    }
    return moves.toOwnedSlice();
}

fn grid_to_graph(grid: [][]const u8, allocator: std.mem.Allocator) !Graph {
    // find all nodes in grid - a node is any position with 3 or more edges
    // seed with the start and end nodes
    var nodes = std.AutoHashMap([2]u16, *Node).init(allocator);

    const start = try allocator.create(Node);
    start.* = .{ .pos = [2]u16{ 0, 1 }, .edges = &[_]Edge{} };
    try nodes.put(start.pos, start);
    const end = try allocator.create(Node);
    end.* = .{ .pos = [2]u16{ @intCast(grid.len - 1), @intCast(grid[0].len - 2) }, .edges = &[_]Edge{} };
    try nodes.put(end.pos, end);

    for (grid, 0..) |row, y| {
        for (row, 0..) |c, x| {
            if (c == '#') {
                continue;
            }
            const possible_moves = try get_moves(grid, @as(u16, @intCast(x)), @as(u16, @intCast(y)), allocator);
            if (possible_moves.len > 2) {
                const node = try allocator.create(Node);
                node.* = .{ .pos = [2]u16{ @as(u16, @intCast(y)), @as(u16, @intCast(x)) }, .edges = &[_]Edge{} };
                try nodes.put(node.*.pos, node);
            }
        }
    }

    var nodes_iter = nodes.valueIterator();
    // walk each node and find all edges
    while (nodes_iter.next()) |node| {
        var edges = std.ArrayList(Edge).init(allocator);
        const moves_from_node = try get_moves(grid, node.*.pos[1], node.*.pos[0], allocator);
        explore_edge: for (moves_from_node) |move| {
            var curr_len: u16 = 1;
            var previous = node.*.pos;
            var current = move;
            var next_moves = try get_moves(grid, move[1], move[0], allocator);
            while (next_moves.len == 2 or previous[0] == 0 or previous[0] == grid.len - 1) {
                for (next_moves) |next_move| {
                    if (next_move[0] == previous[0] and next_move[1] == previous[1]) continue;
                    const other_node = nodes.get(next_move);
                    if (other_node) |n| {
                        // we have reached next node, add the edge
                        try edges.append(Edge{ .len = curr_len + 1, .start_node = node.*, .end_node = n });
                        continue :explore_edge;
                    } else {
                        next_moves = try get_moves(grid, next_move[1], next_move[0], allocator); // keep going
                        previous = current;
                        current = next_move;
                        curr_len += 1;
                        break;
                    }
                }
            }
        }
        node.*.edges = try edges.toOwnedSlice();
    }
    var nodes_array = try allocator.alloc(*Node, nodes.count());
    var nodes_as_list_iter = nodes.valueIterator();
    var i: u16 = 0;
    while (nodes_as_list_iter.next()) |n| : (i += 1) {
        nodes_array[i] = n.*;
    }
    return Graph{ .nodes = nodes_array, .start_node = start, .end_node = end };
}

fn walk_graph(graph: Graph, allocator: std.mem.Allocator) ![]NodePath {
    const start = try allocator.create(NodePath);
    start.* = .{ .node = graph.start_node, .prev = null, .len = 0 };

    var walks = std.ArrayList(*NodePath).init(allocator);
    try walks.append(start);
    var completed_paths = std.ArrayList(NodePath).init(allocator);
    walks: while (walks.items.len > 0) {
        const current_node_path = walks.pop();
        // found the exit
        if (current_node_path.node.equals(graph.end_node.*)) {
            try completed_paths.append(current_node_path.*);
            continue :walks;
        }

        for (current_node_path.node.*.edges) |edge| {
            if (!current_node_path.contains(edge.end_node.*)) {
                const extended_path = try allocator.create(NodePath);
                extended_path.* = .{ .node = edge.end_node, .prev = current_node_path, .len = current_node_path.len + edge.len };
                try walks.append(extended_path);
            }
        }
    }
    return completed_paths.toOwnedSlice();
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const grid = try parse_file("day23/input.txt", allocator);
    const all_walks = try walk(grid, allocator, true);
    var max: u32 = 0;
    for (all_walks) |w| {
        const len = w.len;
        if (len > max) {
            max = len;
        }
    }
    std.debug.print("Part 1 - {d}\n", .{max});

    const graph = try grid_to_graph(grid, allocator);
    const all_paths = try walk_graph(graph, allocator);
    for (all_paths) |path| {
        const len = path.len;
        if (len > max) {
            max = len;
        }
    }
    std.debug.print("Part 2 - {d}\n", .{max});
}
