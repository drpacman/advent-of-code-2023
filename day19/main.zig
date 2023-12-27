const std = @import("std");

// learn how to interact with C library, in this case regex
// from https://www.openmymind.net/Regular-Expressions-in-Zig/
const re = @cImport(@cInclude("regez.h"));

const REGEX_T_ALIGNOF = re.alignof_regex_t;
const REGEX_T_SIZEOF = re.sizeof_regex_t;

const Error = error{ InvalidRegex, FailedMatch, UnexpectedCondition };

const Rule = struct { gate: ?*Gate = null, rule_name: []const u8 };
const Gate = struct { part: u8, condition: Condition, condition_value: u32 };
const Condition = enum { GreaterThan, LessThan };
const Entry = struct {
    rule_name: []const u8,
    rules: []*Rule,
};

const Parts = struct { x: u32, m: u32, a: u32, s: u32 };
const System = struct { parts: []Parts, rule_map: std.StringHashMap(*Entry) };
const GateChain = struct { prev: ?*GateChain, gate: *Gate };

fn compile_regex(allocator: std.mem.Allocator, expression: [*c]const u8) !*re.regex_t {
    // create pointer object of the correct size/alignment on the heap
    const slice = try allocator.alignedAlloc(u8, REGEX_T_ALIGNOF, REGEX_T_SIZEOF);
    // cast it to the expected type
    const regex = @as(*re.regex_t, @ptrCast(slice.ptr));
    if (re.regcomp(regex, expression, re.REG_EXTENDED) != 0) {
        return Error.InvalidRegex;
    }
    return regex;
}

fn parse_file(path: []const u8, allocator: std.mem.Allocator) !*System {
    var rule_map = std.StringHashMap(*Entry).init(allocator);
    var parts = std.ArrayList(Parts).init(allocator);

    const instruction_regex = try compile_regex(allocator, "([a-z]*)\\{([^\\}]+)\\}");
    defer allocator.free(@as([*]u8, @ptrCast(instruction_regex))[0..REGEX_T_SIZEOF]);

    const rule_regex = try compile_regex(allocator, "([a-zA-Z]+)([<>])?([0-9]+)?:?([A-Za-z]*)?");
    defer allocator.free(@as([*]u8, @ptrCast(rule_regex))[0..REGEX_T_SIZEOF]);

    const parts_regex = try compile_regex(allocator, "{x=([0-9]*),m=([0-9]*),a=([0-9]*),s=([0-9]*)}");
    defer allocator.free(@as([*]u8, @ptrCast(parts_regex))[0..REGEX_T_SIZEOF]);

    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    // defer allocator.free(file_contents);
    var lines = std.mem.split(u8, file_contents, "\n");

    var parsing_rules = true;
    while (lines.next()) |line| {
        if (parsing_rules) {
            if (line.len == 0) {
                parsing_rules = false;
                continue;
            }

            var imatches: [3]re.regmatch_t = undefined;
            if (re.regexec(instruction_regex, line.ptr, imatches.len, &imatches, 0) != 0) {
                return Error.FailedMatch;
            }

            var rules = std.ArrayList(*Rule).init(allocator);
            const rule_name: []const u8 = line[@as(usize, @intCast(imatches[1].rm_so))..@as(usize, @intCast(imatches[1].rm_eo))];
            var rules_str = line[@as(usize, @intCast(imatches[2].rm_so))..@as(usize, @intCast(imatches[2].rm_eo))];

            while (rules_str.len > 1) {
                var rule_matches: [5]re.regmatch_t = undefined;
                if (re.regexec(rule_regex, rules_str.ptr, rule_matches.len, &rule_matches, 0) != 0) {
                    return Error.FailedMatch;
                }
                if (rule_matches[2].rm_so != -1) {
                    const part = rules_str[@as(usize, @intCast(rule_matches[1].rm_so))];
                    const condition = switch (rules_str[@as(usize, @intCast(rule_matches[2].rm_so))]) {
                        '>' => Condition.GreaterThan,
                        '<' => Condition.LessThan,
                        else => return Error.FailedMatch,
                    };

                    const condition_value = try std.fmt.parseInt(u32, rules_str[@as(usize, @intCast(rule_matches[3].rm_so))..@as(usize, @intCast(rule_matches[3].rm_eo))], 10);
                    const target_rule_name = rules_str[@as(usize, @intCast(rule_matches[4].rm_so))..@as(usize, @intCast(rule_matches[4].rm_eo))];
                    const gate = try allocator.create(Gate);
                    gate.* = .{ .part = part, .condition = condition, .condition_value = condition_value };
                    const rule = try allocator.create(Rule);
                    rule.* = Rule{ .gate = gate, .rule_name = target_rule_name };
                    try rules.append(rule);
                } else {
                    const target_rule_name = rules_str[@as(usize, @intCast(rule_matches[1].rm_so))..@as(usize, @intCast(rule_matches[1].rm_eo))];
                    const rule = try allocator.create(Rule);
                    rule.* = Rule{ .rule_name = target_rule_name };
                    try rules.append(rule);
                }
                rules_str = rules_str[@intCast(rule_matches[0].rm_eo)..];
            }
            const entry = try allocator.create(Entry);
            entry.* = .{ .rule_name = rule_name, .rules = try rules.toOwnedSlice() };
            try rule_map.put(rule_name, entry);
        } else {
            // handle parts
            var part_matches: [5]re.regmatch_t = undefined;
            if (re.regexec(parts_regex, line.ptr, part_matches.len, &part_matches, 0) != 0) {
                break;
            }
            const x = try std.fmt.parseInt(u32, line[@as(usize, @intCast(part_matches[1].rm_so))..@as(usize, @intCast(part_matches[1].rm_eo))], 10);
            const m = try std.fmt.parseInt(u32, line[@as(usize, @intCast(part_matches[2].rm_so))..@as(usize, @intCast(part_matches[2].rm_eo))], 10);
            const a = try std.fmt.parseInt(u32, line[@as(usize, @intCast(part_matches[3].rm_so))..@as(usize, @intCast(part_matches[3].rm_eo))], 10);
            const s = try std.fmt.parseInt(u32, line[@as(usize, @intCast(part_matches[4].rm_so))..@as(usize, @intCast(part_matches[4].rm_eo))], 10);
            try parts.append(Parts{ .x = x, .m = m, .a = a, .s = s });
        }
    }
    const system = try allocator.create(System);
    system.* = .{ .parts = try parts.toOwnedSlice(), .rule_map = rule_map };
    return system;
}

fn part1(system: *System) u32 {
    var total: u32 = 0;
    for (system.parts) |part| {
        var curr_rule: []const u8 = "in";
        var entry = system.rule_map.get(curr_rule);

        const accepted = validate: while (entry != null) : (entry = system.rule_map.get(curr_rule)) {
            curr_rule = for (entry.?.rules) |rule| {
                if (rule.gate) |g| {
                    if ((g.part == 'x' and g.condition == Condition.GreaterThan and part.x > g.condition_value) or
                        (g.part == 'x' and g.condition == Condition.LessThan and part.x < g.condition_value) or
                        (g.part == 'm' and g.condition == Condition.GreaterThan and part.m > g.condition_value) or
                        (g.part == 'm' and g.condition == Condition.LessThan and part.m < g.condition_value) or
                        (g.part == 'a' and g.condition == Condition.GreaterThan and part.a > g.condition_value) or
                        (g.part == 'a' and g.condition == Condition.LessThan and part.a < g.condition_value) or
                        (g.part == 's' and g.condition == Condition.GreaterThan and part.s > g.condition_value) or
                        (g.part == 's' and g.condition == Condition.LessThan and part.s < g.condition_value))
                    {
                        break rule.rule_name;
                    }
                } else {
                    break rule.rule_name;
                }
            } else unreachable;

            if (std.mem.eql(u8, curr_rule, "A")) {
                break :validate true;
            } else if (std.mem.eql(u8, curr_rule, "R")) {
                break :validate false;
            }
        } else false;

        if (accepted) {
            total += part.x + part.m + part.a + part.s;
        }
    }
    return total;
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const system = try parse_file("day19/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{part1(system)});
    std.debug.print("Part2 - {d}\n", .{try part2(system, allocator)});
}

fn part2(system: *System, allocator: std.mem.Allocator) !u64 {
    var total: u64 = 0;
    const gate_chains = try build_rule_chains(system, "in", null, allocator);
    // calculate min/max ranges per path
    next_chain: for (gate_chains) |gate_chain| {
        var region = [4][2]u32{ [2]u32{ 1, 4000 }, [2]u32{ 1, 4000 }, [2]u32{ 1, 4000 }, [2]u32{ 1, 4000 } };
        var curr_chain: ?*GateChain = gate_chain;
        while (curr_chain) |chain| : (curr_chain = curr_chain.?.prev) {
            const gate = chain.gate;
            const part_index: usize = switch (gate.part) {
                'x' => 0,
                'm' => 1,
                'a' => 2,
                's' => 3,
                else => unreachable,
            };
            if (gate.condition == Condition.LessThan) {
                region[part_index][1] = @min(region[part_index][1], gate.condition_value - 1);
            } else if (gate.condition == Condition.GreaterThan) {
                region[part_index][0] = @max(region[part_index][0], gate.condition_value + 1);
            } else {
                return error.UnexpectedCondition;
            }
            if (region[part_index][0] > region[part_index][1]) continue :next_chain;
        }
        var region_size: u64 = 1;
        for (0..4) |i| {
            region_size *= (region[i][1] - region[i][0] + 1);
        }
        total += region_size;
    }

    return @as(u64, total);
}

fn build_rule_chains(system: *System, rule_name: []const u8, gate_chain: ?*GateChain, allocator: std.mem.Allocator) ![]*GateChain {
    var gate_chains = std.ArrayList(*GateChain).init(allocator);
    if (std.mem.eql(u8, rule_name, "A") and gate_chain != null) {
        try gate_chains.append(gate_chain.?);
    } else if (!std.mem.eql(u8, rule_name, "R")) {
        const entry = system.rule_map.get(rule_name).?;
        var curr_gate_chain = gate_chain;
        const max_index = entry.rules.len - 1;

        for (
            0..max_index,
        ) |i| {
            const gate = entry.rules[i].gate.?;
            const next_gate_chain = try allocator.create(GateChain);
            next_gate_chain.* = .{ .prev = curr_gate_chain, .gate = gate };

            // append this condition being true
            const chains = try build_rule_chains(system, entry.rules[i].rule_name, next_gate_chain, allocator);
            for (chains) |chain| {
                try gate_chains.append(chain);
            }
            // append this condition not being true
            const negated_gate = try allocator.create(Gate);
            switch (gate.condition) {
                Condition.GreaterThan => {
                    negated_gate.* = .{ .condition = Condition.LessThan, .condition_value = gate.condition_value + 1, .part = gate.part };
                },
                Condition.LessThan => {
                    negated_gate.* = .{ .condition = Condition.GreaterThan, .condition_value = gate.condition_value - 1, .part = gate.part };
                },
            }

            const negated_next_gate_chain = try allocator.create(GateChain);
            negated_next_gate_chain.* = .{ .prev = curr_gate_chain, .gate = negated_gate };
            curr_gate_chain = negated_next_gate_chain;
        }
        const chains = try build_rule_chains(system, entry.rules[max_index].rule_name, curr_gate_chain, allocator);
        for (chains) |chain| {
            try gate_chains.append(chain);
        }
    }
    return try gate_chains.toOwnedSlice();
}
