const std = @import("std");

const ModuleTypeTag = enum {
    broadcast,
    flip_flop,
    nand,
};

const ModuleType = union(ModuleTypeTag) {
    broadcast: Broadcast,
    flip_flop: *FlipFlop,
    nand: *Nand,
};

const Error = error{ ExpectedNand, MissingTarget };

const Module = struct { destinations: [][]const u8, module_type: ModuleType };
const Broadcast = struct {};
const FlipFlop = struct { on: bool = false };
const Value = struct { last_high_counter: u64, value: bool };

const Nand = struct {
    state: std.StringHashMap(Value),

    fn register_input(self: *Nand, name: []const u8) !void {
        try self.state.put(name, Value{ .last_high_counter = 0, .value = false });
    }

    fn set_pulse(self: *Nand, name: []const u8, is_high: bool, counter: u64) !void {
        if (is_high) {
            // update the last counter for going high
            try self.state.put(name, Value{ .last_high_counter = counter, .value = true });
        } else {
            const existing = self.state.get(name).?.last_high_counter;
            try self.state.put(name, Value{ .last_high_counter = existing, .value = false });
        }
    }

    fn is_high_output(self: *Nand) bool {
        var iter = self.state.valueIterator();
        while (iter.next()) |value| {
            if (!value.value == true) {
                return true;
            }
        }
        return false;
    }

    fn lcm(a: u64, b: u64) u64 {
        return (a * b) / std.math.gcd(a, b);
    }

    fn get_state_cycle(self: Nand) ?u64 {
        // if we have a counter value for every input going high
        // calculate the lowest common multiple of all of them
        // this is the cycle length
        var iter = self.state.valueIterator();
        var cycle_length: u64 = 1;
        while (iter.next()) |value| {
            if (value.*.last_high_counter == 0) return null;
            cycle_length = lcm(cycle_length, value.last_high_counter);
        }
        return cycle_length;
    }
};

fn parse_file(path: []const u8, allocator: std.mem.Allocator) !std.StringHashMap(Module) {
    const file_contents = try std.fs.cwd().readFileAlloc(allocator, path, 1e6);
    var lines = std.mem.split(u8, file_contents, "\n");
    var modules = std.StringHashMap(Module).init(allocator);
    while (lines.next()) |line| {
        var parts = std.mem.split(u8, line, " ");
        var module_type = ModuleType.broadcast;
        var name = parts.next().?;
        if (name[0] == '%') {
            module_type = ModuleType.flip_flop;
            name = name[1..];
        } else if (name[0] == '&') {
            module_type = ModuleType.nand;
            name = name[1..];
        }
        _ = parts.next();
        var dests = std.ArrayList([]const u8).init(allocator);
        while (parts.next()) |part| {
            if (parts.peek() != null) {
                try dests.append(part[0 .. part.len - 1]);
            } else {
                try dests.append(part);
            }
        }
        const destinations = try dests.toOwnedSlice();
        switch (module_type) {
            ModuleTypeTag.broadcast => {
                try modules.put(name, Module{ .destinations = destinations, .module_type = ModuleType{ .broadcast = Broadcast{} } });
            },
            ModuleTypeTag.flip_flop => {
                const flip_flop = try allocator.create(FlipFlop);
                try modules.put(name, Module{ .destinations = destinations, .module_type = ModuleType{ .flip_flop = flip_flop } });
            },
            ModuleTypeTag.nand => {
                const nand = try allocator.create(Nand);
                nand.* = .{ .state = std.StringHashMap(Value).init(allocator) };
                try modules.put(name, Module{ .destinations = destinations, .module_type = ModuleType{ .nand = nand } });
            },
        }
    }

    // update all Nands with their inputs
    var key_iter = modules.keyIterator();
    while (key_iter.next()) |key| {
        const destinations = modules.get(key.*).?.destinations;
        for (destinations) |dest| {
            if (modules.get(dest)) |target_module| {
                if (target_module.module_type == ModuleTypeTag.nand) {
                    try target_module.module_type.nand.register_input(key.*);
                }
            }
        }
    }
    return modules;
}

const Pulse = struct {
    target: []const u8,
    src: []const u8,
    is_high: bool,
};

fn press_button(modules: std.StringHashMap(Module), allocator: std.mem.Allocator, counter: u64) ![2]u64 {
    var queue = std.ArrayList(Pulse).init(allocator);
    try queue.append(Pulse{ .src = "button", .target = "broadcaster", .is_high = false });

    var low_count: u64 = 1;
    var high_count: u64 = 0;
    var pulses = try queue.toOwnedSlice();
    while (pulses.len > 0) {
        for (pulses) |pulse| {
            if (modules.get(pulse.target)) |module| {
                var high_output_pulse = false;
                switch (module.module_type) {
                    ModuleTypeTag.broadcast => {
                        high_output_pulse = pulse.is_high;
                    },
                    ModuleTypeTag.flip_flop => {
                        if (pulse.is_high) continue;
                        // flip the state of the flip flop on a low pulse
                        module.module_type.flip_flop.on = !module.module_type.flip_flop.on;
                        high_output_pulse = module.module_type.flip_flop.on;
                    },
                    ModuleTypeTag.nand => {
                        // update state
                        const nand = module.module_type.nand;
                        try nand.set_pulse(pulse.src, pulse.is_high, counter);
                        high_output_pulse = nand.is_high_output();
                    },
                }
                for (module.destinations) |dest| {
                    if (high_output_pulse) {
                        high_count += 1;
                    } else {
                        low_count += 1;
                    }
                    try queue.append(Pulse{ .target = dest, .src = pulse.target, .is_high = high_output_pulse });
                }
            }
        }
        pulses = try queue.toOwnedSlice();
    }
    return [2]u64{ low_count, high_count };
}

fn part1(modules: std.StringHashMap(Module), allocator: std.mem.Allocator) !u64 {
    var total_count: [2]u64 = [2]u64{ 0, 0 };
    for (0..1000) |i| {
        const result = try press_button(modules, allocator, i);
        total_count[0] += result[0];
        total_count[1] += result[1];
    }
    return total_count[0] * total_count[1];
}

fn part2(modules: std.StringHashMap(Module), allocator: std.mem.Allocator) !u64 {
    // find the entry with an output of rx
    var key_iter = modules.keyIterator();
    const nand_to_monitor = while (key_iter.next()) |key| {
        const module = modules.get(key.*).?;
        if (std.mem.eql(u8, module.destinations[0], "rx")) {
            // make sure its a Nand
            if (module.module_type != ModuleTypeTag.nand) {
                return Error.ExpectedNand;
            }
            break key.*;
        }
    } else return Error.MissingTarget;

    var i: u64 = 1;
    while (true) : (i += 1) {
        _ = try press_button(modules, allocator, i);
        const module = modules.get(nand_to_monitor).?;
        const result = module.module_type.nand.get_state_cycle();
        if (result != null) {
            return result.?;
        }
    }
    return i;
}

fn reset(modules: std.StringHashMap(Module)) void {
    var key_iter = modules.keyIterator();
    while (key_iter.next()) |key| {
        const module = modules.get(key.*).?;
        switch (module.module_type) {
            ModuleTypeTag.flip_flop => {
                module.module_type.flip_flop.on = false;
            },
            ModuleTypeTag.nand => {
                var iter = module.module_type.nand.state.valueIterator();
                while (iter.next()) |value| {
                    value.* = Value{ .last_high_counter = 0, .value = false };
                }
            },
            else => {},
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    const modules = try parse_file("day20/input.txt", allocator);
    std.debug.print("Part1 - {d}\n", .{try part1(modules, allocator)});
    reset(modules);
    std.debug.print("Part2 - {d}\n", .{try part2(modules, allocator)});
}
