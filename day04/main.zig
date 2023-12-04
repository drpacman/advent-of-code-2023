const std = @import("std");

fn parse_file(name: []const u8, buffer: []u8, allocator: std.mem.Allocator) !std.ArrayList(Card) {
    var list = std.ArrayList(Card).init(allocator);
    const contents: []const u8 = try std.fs.cwd().readFile(name, buffer);
    var iter = std.mem.split(u8, contents, "\n");

    while (iter.next()) |line| {
        var iter1 = std.mem.split(u8, line, ":");
        _ = iter1.next();
        var iter2 = std.mem.split(u8, iter1.next().?, "|");
        const winner = (try parse_entries(iter2.next().?, allocator)).items;
        const deck = (try parse_entries(iter2.next().?, allocator)).items;
        const card = Card{ .winner = winner, .deck = deck };
        try list.append(card);
    }
    return list;
}

fn parse_entries(entries: []const u8, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var result = std.ArrayList(u8).init(allocator);
    var iter = std.mem.split(u8, std.mem.trim(u8, entries, " "), " ");
    while (iter.next()) |value| {
        if (value.len == 0) continue;
        try result.append(try std.fmt.parseInt(u8, value, 10));
    }
    return result;
}

fn score_card(card: Card) u32 {
    std.mem.sort(u8, card.winner, {}, std.sort.asc(u8));
    std.mem.sort(u8, card.deck, {}, std.sort.asc(u8));
    var w: u8 = 0;
    var d: u8 = 0;
    var count: u32 = 0;
    while (w < card.winner.len and d < card.deck.len) {
        if (card.winner[w] == card.deck[d]) {
            count += 1;
            w += 1;
            d += 1;
        } else if (card.winner[w] > card.deck[d]) {
            d += 1;
        } else {
            w += 1;
        }
    }
    return count;
}
fn part1(cards: []Card) u32 {
    var result: u32 = 0;
    for (cards) |card| {
        const count = score_card(card);
        if (count > 0) {
            const score = std.math.pow(u32, 2, count - 1);
            result += score;
        }
    }
    return result;
}

fn part2(cards: []Card, allocator: std.mem.Allocator) !u64 {
    var counts = try allocator.alloc(u32, cards.len);
    for (counts) |*count| {
        count.* = 1;
    }
    for (cards, 0..) |card, index| {
        const next_n = score_card(card);
        if (next_n > 0) {
            for (1..next_n + 1) |n| {
                counts[index + n] += counts[index];
            }
        }
    }
    var sum: u64 = 0;
    for (counts) |count| {
        sum += count;
    }

    return sum;
}

const Card = struct {
    winner: []u8,
    deck: []u8,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const buf = try allocator.alloc(u8, 1e6);

    const cards = try parse_file("day04/input.txt", buf, allocator);
    std.debug.print("Part1 - {d}\n", .{part1(cards.items)});
    std.debug.print("Part2 - {d}\n", .{try part2(cards.items, allocator)});
}

test "part1" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const buf = try allocator.alloc(u8, 1e6);

    const cards = try parse_file("day04/test.txt", buf, allocator);
    try std.testing.expectEqual(cards.items.len, 6);
    try std.testing.expectEqual(cards.items[0].winner.len, 5);
    try std.testing.expectEqual(cards.items[0].deck.len, 8);
    try std.testing.expectEqual(part1(cards.items), 13);
}

test "part2" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const buf = try allocator.alloc(u8, 1e6);

    const cards = try parse_file("day04/test.txt", buf, allocator);
    try std.testing.expectEqual(try part2(cards.items, allocator), 30);
}
