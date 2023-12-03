const std = @import("std");
const split = std.mem.split;
const eql = std.mem.eql;
const max_file_read_1_mb = (1 << 10) << 10;

fn parseFile(allocator: std.mem.Allocator) ![]Game {
    const contents: []const u8 = try std.fs.cwd().readFileAlloc(allocator, "day02/test.txt", max_file_read_1_mb);
    defer allocator.free(contents);
    var lines = split(u8, contents, "\n");
    var games = std.ArrayList(Game).init(allocator);
    while (lines.next()) |line| {
        const game = try parseGame(line, allocator);
        try games.append(game);
    }
    return games.items;
}

fn parseGame(line: []const u8, allocator: std.mem.Allocator) !Game {
    var game_parts = split(u8, line, ":");
    // games are in numbered order so we can ignore first bit
    _ = game_parts.next();
    var rounds_str = split(u8, game_parts.next().?, ";");
    var rounds = std.ArrayList(Round).init(allocator);
    while (rounds_str.next()) |round_str| {
        var colours = split(u8, round_str, ",");
        var round = Round{};
        while (colours.next()) |colour_count| {
            const trimmed_str = std.mem.trim(u8, colour_count, " ");
            var colour_count_iter = split(u8, trimmed_str, " ");
            const count: u8 = try std.fmt.parseInt(u8, colour_count_iter.next().?, 10);
            const c = colour_count_iter.next().?;
            if (eql(u8, c, "red")) {
                round.red = count;
            } else if (eql(u8, c, "blue")) {
                round.blue = count;
            } else if (eql(u8, c, "green")) {
                round.green = count;
            }
        }
        try rounds.append(round);
    }
    return Game{ .rounds = rounds.items };
}

const Round = struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
};

const Game = struct {
    rounds: []Round,

    fn is_valid(self: Game) bool {
        for (self.rounds) |round| {
            if (round.red > 12 or round.green > 13 or round.blue > 14) return false;
        }
        return true;
    }

    fn power(self: Game) u64 {
        var max_red: u64 = 0;
        var max_green: u64 = 0;
        var max_blue: u64 = 0;
        for (self.rounds) |round| {
            if (round.red > max_red) max_red = round.red;
            if (round.green > max_green) max_green = round.green;
            if (round.blue > max_blue) max_blue = round.blue;
        }
        return max_red * max_green * max_blue;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const games = try parseFile(allocator);
    var part1: u32 = 0;
    for (games, 1..) |game, index| {
        if (game.is_valid()) {
            part1 += @intCast(index);
        }
    }
    std.debug.print("Part 1 - {d}\n", .{part1});

    var part2: u64 = 0;
    for (games) |game| {
        part2 += game.power();
    }
    std.debug.print("Part 2 - {d}\n", .{part2});
}

test "parsing game" {
    const value = "Game 1: 1 red, 2 blue; 3 red, 4 blue, 3 green";
    const game: Game = try parseGame(value, std.testing.allocator);
    try std.testing.expectEqual(game.rounds[0].red, 1);
    try std.testing.expectEqual(game.rounds[1].red, 3);
}
