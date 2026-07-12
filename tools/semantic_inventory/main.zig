const std = @import("std");

const Error = error{
    InvalidArguments,
    MissingDeviceFeatures,
    InvalidFeatureField,
    DuplicateFeatureField,
    MissingFeatureMapping,
    UnknownFeatureMapping,
    EmptySemanticMapping,
    DuplicateSemanticId,
    UnknownSemanticId,
    InvalidLedgerRow,
    InvalidCoverageStatus,
    InvalidEvidenceStatus,
    ExecutableWithoutEvidence,
};

const coverage_statuses = [_][]const u8{
    "native-exact",
    "composed-exact",
    "emulated-exact",
    "unsupported",
    "incomplete",
    "not-applicable",
};

const evidence_statuses = [_][]const u8{
    "inspection",
    "unit",
    "gpu-smoke",
    "gpu-pixels",
    "gpu-soak",
    "missing",
};

pub fn main(init: std.process.Init.Minimal) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try init.args.toSlice(allocator);
    if (args.len != 7) return Error.InvalidArguments;

    const core_source = try readFile(allocator, args[1], 8 * 1024 * 1024);
    const inventory = try readFile(allocator, args[2], 8 * 1024 * 1024);
    const feature_map = try readFile(allocator, args[3], 2 * 1024 * 1024);
    const ledger = try readFile(allocator, args[4], 8 * 1024 * 1024);
    const protocol_map = try readFile(allocator, args[5], 2 * 1024 * 1024);
    const gap_routing = try readFile(allocator, args[6], 2 * 1024 * 1024);

    var feature_fields = std.StringHashMap(void).init(allocator);
    try parseDeviceFeatureFields(core_source, &feature_fields);

    var semantic_ids = std.StringHashMap(void).init(allocator);
    try parseInventoryIds(inventory, &semantic_ids);

    try validateFeatureMap(feature_map, feature_fields, semantic_ids, allocator);
    var incomplete_ids = std.StringHashMap(void).init(allocator);
    const ledger_count = try validateLedger(ledger, allocator, &incomplete_ids);
    const protocol_count = try validateProtocolMap(protocol_map, ledger, allocator);
    try validateGapRouting(gap_routing, incomplete_ids, allocator);

    std.debug.print(
        "semantic inventory ok: device_features={d} inventory_ids={d} metal_semantics={d} metal_protocols={d} routed_gaps={d}\n",
        .{ feature_fields.count(), semantic_ids.count(), ledger_count, protocol_count, incomplete_ids.count() },
    );
}

fn readFile(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ![]u8 {
    const io = std.Options.debug_io;
    const parent = std.fs.path.dirname(path) orelse return std.Io.Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .limited(max_bytes),
    );
    var dir = if (std.fs.path.isAbsolute(parent))
        try std.Io.Dir.openDirAbsolute(io, parent, .{})
    else
        try std.Io.Dir.cwd().openDir(io, parent, .{});
    defer dir.close(io);
    return dir.readFileAlloc(io, std.fs.path.basename(path), allocator, .limited(max_bytes));
}

fn parseDeviceFeatureFields(source: []const u8, fields: *std.StringHashMap(void)) !void {
    const start_marker = "pub const DeviceFeatures = struct {";
    const start = std.mem.indexOf(u8, source, start_marker) orelse return Error.MissingDeviceFeatures;
    const body_start = start + start_marker.len;
    const body_end = std.mem.indexOfPos(u8, source, body_start, "\n};") orelse return Error.MissingDeviceFeatures;
    var lines = std.mem.splitScalar(u8, source[body_start..body_end], '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or std.mem.startsWith(u8, line, "//")) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return Error.InvalidFeatureField;
        const name = line[0..colon];
        if (name.len == 0) return Error.InvalidFeatureField;
        const result = try fields.getOrPut(name);
        if (result.found_existing) return Error.DuplicateFeatureField;
    }
}

fn parseInventoryIds(source: []const u8, ids: *std.StringHashMap(void)) !void {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "| ")) continue;
        const rest = line[2..];
        const separator = std.mem.indexOf(u8, rest, " |") orelse continue;
        const id = rest[0..separator];
        if (!isInventoryId(id)) continue;
        const result = try ids.getOrPut(id);
        if (result.found_existing) return Error.DuplicateSemanticId;
    }
}

fn validateFeatureMap(
    source: []const u8,
    feature_fields: std.StringHashMap(void),
    semantic_ids: std.StringHashMap(void),
    allocator: std.mem.Allocator,
) !void {
    var mapped_fields = std.StringHashMap(void).init(allocator);
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var columns = std.mem.splitScalar(u8, line, '\t');
        const field = columns.next() orelse return Error.UnknownFeatureMapping;
        const mappings = columns.next() orelse return Error.EmptySemanticMapping;
        if (columns.next() != null or mappings.len == 0) return Error.EmptySemanticMapping;
        if (!feature_fields.contains(field)) return Error.UnknownFeatureMapping;
        const result = try mapped_fields.getOrPut(field);
        if (result.found_existing) return Error.DuplicateFeatureField;

        var mapping_it = std.mem.splitScalar(u8, mappings, ',');
        while (mapping_it.next()) |id| {
            if (id.len == 0 or !semantic_ids.contains(id)) return Error.UnknownSemanticId;
        }
    }

    var field_it = feature_fields.keyIterator();
    while (field_it.next()) |field| {
        if (!mapped_fields.contains(field.*)) return Error.MissingFeatureMapping;
    }
}

fn validateLedger(
    source: []const u8,
    allocator: std.mem.Allocator,
    incomplete_ids: *std.StringHashMap(void),
) !usize {
    var ids = std.StringHashMap(void).init(allocator);
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "| MTL-")) continue;
        const row = std.mem.trimEnd(u8, line[2..], " |\t\r");
        var columns = std.mem.splitSequence(u8, row, " | ");
        const id = columns.next() orelse return Error.InvalidLedgerRow;
        _ = columns.next() orelse return Error.InvalidLedgerRow; // Metal source family
        _ = columns.next() orelse return Error.InvalidLedgerRow; // semantic contract
        _ = columns.next() orelse return Error.InvalidLedgerRow; // owner
        const metal = columns.next() orelse return Error.InvalidLedgerRow;
        const vulkan = columns.next() orelse return Error.InvalidLedgerRow;
        _ = columns.next() orelse return Error.InvalidLedgerRow; // Vulkan mapping/gates
        const evidence = columns.next() orelse return Error.InvalidLedgerRow;
        if (columns.next() != null) return Error.InvalidLedgerRow;

        if (!isMetalSemanticId(id)) return Error.InvalidLedgerRow;
        const result = try ids.getOrPut(id);
        if (result.found_existing) return Error.DuplicateSemanticId;
        if (!containsToken(&coverage_statuses, metal)) return Error.InvalidCoverageStatus;
        if (!containsToken(&coverage_statuses, vulkan)) return Error.InvalidCoverageStatus;
        if (!containsToken(&evidence_statuses, evidence)) return Error.InvalidEvidenceStatus;
        if (std.mem.eql(u8, evidence, "missing") and (isExecutable(metal) or isExecutable(vulkan))) {
            return Error.ExecutableWithoutEvidence;
        }
        if (std.mem.eql(u8, metal, "incomplete") or std.mem.eql(u8, vulkan, "incomplete")) {
            try incomplete_ids.put(id, {});
        }
    }
    if (ids.count() == 0) return Error.InvalidLedgerRow;
    return ids.count();
}

fn validateGapRouting(
    source: []const u8,
    incomplete_ids: std.StringHashMap(void),
    allocator: std.mem.Allocator,
) !void {
    var routed = std.StringHashMap(void).init(allocator);
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var columns = std.mem.splitScalar(u8, line, '\t');
        const id = columns.next() orelse return Error.InvalidLedgerRow;
        const period = columns.next() orelse return Error.InvalidLedgerRow;
        if (columns.next() != null or period.len != 3 or period[0] != 'P' or
            period[1] < '0' or period[1] > '9' or period[2] < '0' or period[2] > '9')
        {
            return Error.InvalidLedgerRow;
        }
        if (!incomplete_ids.contains(id)) return Error.UnknownSemanticId;
        const result = try routed.getOrPut(id);
        if (result.found_existing) return Error.DuplicateSemanticId;
    }

    if (routed.count() != incomplete_ids.count()) return Error.MissingFeatureMapping;
    var incomplete_it = incomplete_ids.keyIterator();
    while (incomplete_it.next()) |id| {
        if (!routed.contains(id.*)) return Error.MissingFeatureMapping;
    }
}

fn validateProtocolMap(source: []const u8, ledger: []const u8, allocator: std.mem.Allocator) !usize {
    var protocols = std.StringHashMap(void).init(allocator);
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        var columns = std.mem.splitScalar(u8, line, '\t');
        const protocol = columns.next() orelse return Error.InvalidLedgerRow;
        const mappings = columns.next() orelse return Error.EmptySemanticMapping;
        if (columns.next() != null or !std.mem.startsWith(u8, protocol, "MTL")) return Error.InvalidLedgerRow;
        const result = try protocols.getOrPut(protocol);
        if (result.found_existing) return Error.DuplicateFeatureField;

        var mapping_it = std.mem.splitScalar(u8, mappings, ',');
        while (mapping_it.next()) |id| {
            if (!isMetalSemanticId(id) or std.mem.indexOf(u8, ledger, id) == null) return Error.UnknownSemanticId;
        }
    }
    if (protocols.count() != 78) return Error.InvalidLedgerRow;
    return protocols.count();
}

fn isInventoryId(id: []const u8) bool {
    const dash = std.mem.indexOfScalar(u8, id, '-') orelse return false;
    if (dash < 2 or dash > 3 or id.len != dash + 3) return false;
    for (id[0..dash]) |c| if (c < 'A' or c > 'Z') return false;
    for (id[dash + 1 ..]) |c| if (c < '0' or c > '9') return false;
    return true;
}

fn isMetalSemanticId(id: []const u8) bool {
    if (!std.mem.startsWith(u8, id, "MTL-")) return false;
    var dashes: usize = 0;
    for (id) |c| {
        if (c == '-') dashes += 1;
    }
    return dashes == 2 and id.len >= 10;
}

fn containsToken(tokens: []const []const u8, value: []const u8) bool {
    for (tokens) |token| if (std.mem.eql(u8, token, value)) return true;
    return false;
}

fn isExecutable(status: []const u8) bool {
    return std.mem.eql(u8, status, "native-exact") or
        std.mem.eql(u8, status, "composed-exact") or
        std.mem.eql(u8, status, "emulated-exact");
}

test "inventory and ledger token helpers stay strict" {
    try std.testing.expect(isInventoryId("RES-01"));
    try std.testing.expect(!isInventoryId("RES-1"));
    try std.testing.expect(isMetalSemanticId("MTL-DEV-001"));
    try std.testing.expect(!isMetalSemanticId("DEV-001"));
    try std.testing.expect(isExecutable("composed-exact"));
    try std.testing.expect(!isExecutable("incomplete"));
}
