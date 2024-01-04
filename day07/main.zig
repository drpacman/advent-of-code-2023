const std = @import("std");

const Hand = struct { cards: []const u8, bid: u16 };

fn parse_file(path: []const u8, allocator: std.mem.Allocator) ![]Hand {
    var hands = std.ArrayList(Hand).init(allocator);
    defer hands.deinit();

    var file = try std.fs.cwd().openFile(path, .{});
    const file_contents = try file.readToEndAlloc(allocator, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    while (lines.next()) |line| {
        try hands.append(Hand{ .cards = line[0..5], .bid = try std.fmt.parseInt(u16, line[6..], 10) });
    }
    return hands.toOwnedSlice();
}

const HandRanks = enum(u4) { HIGH_CARD = 1, ONE_PAIR = 2, TWO_PAIR = 3, THREE_OF_A_KIND = 4, FULL_HOUSE = 5, FOUR_OF_A_KIND = 6, FIVE_OF_A_KIND = 7 };

fn get_num(card: u8) u8 {
    if (card >= '1' and card <= '9') {
        return card - '0';
    } else if (card == 'T') {
        return 10;
    } else if (card == 'J') {
        return 11;
    } else if (card == 'Q') {
        return 12;
    } else if (card == 'K') {
        return 13;
    } else if (card == 'A') {
        return 14;
    } else {
        std.debug.panic("invalid card: {c}\n", .{card});
    }
}

fn get_num_card_part2(card: u8) u8 {
    if (card == 'J') {
        return 0;
    }
    return get_num(card);
}

fn rank_hand(hand: Hand) HandRanks {
    var counts = [_]u8{0} ** 15;
    for (hand.cards) |card| {
        const i = get_num(card);
        counts[i] += 1;
    }
    var pair_count: u2 = 0;
    var has_three = false;
    var has_four = false;
    var has_five = false;
    for (counts) |count| {
        switch (count) {
            2 => pair_count += 1,
            3 => has_three = true,
            4 => has_four = true,
            5 => has_five = true,
            else => continue,
        }
    }
    if (has_five) {
        return HandRanks.FIVE_OF_A_KIND;
    } else if (has_four) {
        return HandRanks.FOUR_OF_A_KIND;
    } else if (has_three) {
        if (pair_count == 1) {
            return HandRanks.FULL_HOUSE;
        } else {
            return HandRanks.THREE_OF_A_KIND;
        }
    } else if (pair_count == 2) {
        return HandRanks.TWO_PAIR;
    } else if (pair_count == 1) {
        return HandRanks.ONE_PAIR;
    } else {
        return HandRanks.HIGH_CARD;
    }
}

fn rank_hand_part2(hand: Hand) HandRanks {
    var counts = [_]u8{0} ** 15;
    for (hand.cards) |card| {
        const i = get_num_card_part2(card);
        counts[i] += 1;
    }
    var pair_count: u2 = 0;
    var has_three = false;
    var has_four = false;
    var has_five = false;
    for (
        counts[1..],
    ) |count| {
        switch (count) {
            2 => pair_count += 1,
            3 => has_three = true,
            4 => has_four = true,
            5 => has_five = true,
            else => continue,
        }
    }
    // apply wild cards boost ranks
    var rank = HandRanks.HIGH_CARD;
    switch (counts[0]) {
        0 => {
            if (has_four) {
                rank = HandRanks.FOUR_OF_A_KIND;
            } else if (has_three) {
                if (pair_count == 1) {
                    rank = HandRanks.FULL_HOUSE;
                } else {
                    rank = HandRanks.THREE_OF_A_KIND;
                }
            } else if (pair_count == 2) {
                rank = HandRanks.TWO_PAIR;
            } else if (pair_count == 1) {
                rank = HandRanks.ONE_PAIR;
            } else {
                rank = HandRanks.HIGH_CARD;
            }
        },
        1 => {
            if (has_four) {
                rank = HandRanks.FIVE_OF_A_KIND;
            } else if (has_three) {
                rank = HandRanks.FOUR_OF_A_KIND;
            } else if (pair_count == 2) {
                rank = HandRanks.FULL_HOUSE;
            } else if (pair_count == 1) {
                rank = HandRanks.THREE_OF_A_KIND;
            } else {
                rank = HandRanks.ONE_PAIR;
            }
        },
        2 => {
            if (has_three) {
                rank = HandRanks.FIVE_OF_A_KIND;
            } else if (pair_count == 1) {
                rank = HandRanks.FOUR_OF_A_KIND;
            } else {
                rank = HandRanks.THREE_OF_A_KIND;
            }
        },
        3 => {
            if (pair_count > 0) {
                rank = HandRanks.FIVE_OF_A_KIND;
            } else {
                rank = HandRanks.FOUR_OF_A_KIND;
            }
        },
        4 => rank = HandRanks.FIVE_OF_A_KIND,
        else => rank = HandRanks.FIVE_OF_A_KIND,
    }
    return rank;
}

fn compare(a: Hand, b: Hand, comptime ranker: fn (Hand) HandRanks, comptime get_number: fn (u8) u8) bool {
    const a_rank = ranker(a);
    const b_rank = ranker(b);
    if (a_rank != b_rank) {
        return @intFromEnum(a_rank) < @intFromEnum(b_rank);
    }
    for (a.cards, b.cards) |a_card, b_card| {
        const a_val = get_number(a_card);
        const b_val = get_number(b_card);
        if (a_val == b_val) continue;
        return a_val < b_val;
    }
    return false;
}

fn compare_hands(_: void, a: Hand, b: Hand) bool {
    return compare(a, b, rank_hand, get_num);
}

fn compare_hands_part2(_: void, a: Hand, b: Hand) bool {
    return compare(a, b, rank_hand_part2, get_num_card_part2);
}

fn part1(hands: []Hand) u64 {
    std.mem.sort(Hand, hands, {}, compare_hands);
    var result: u64 = 0;
    for (hands, 1..) |hand, index| {
        result += (index * hand.bid);
    }
    return result;
}

fn part2(hands: []Hand) u64 {
    std.mem.sort(Hand, hands, {}, compare_hands_part2);
    var result: u64 = 0;
    for (hands, 1..) |hand, index| {
        result += (index * hand.bid);
    }
    return result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hands = try parse_file("day07/input.txt", allocator);
    std.debug.print("Part 1: {d} \n", .{part1(hands)});
    std.debug.print("Part 2: {d} \n", .{part2(hands)});
}

test "rank hands part 1" {
    const allocator = std.heap.page_allocator;
    const hands = try parse_file("day07/test.txt", allocator);
    try std.testing.expectEqual(part1(hands), 6440);
}

test "rank hands part 2" {
    const allocator = std.heap.page_allocator;
    const hands = try parse_file("day07/test.txt", allocator);
    try std.testing.expectEqual(part2(hands), 5905);
}
