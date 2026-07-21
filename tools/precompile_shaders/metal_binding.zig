const std = @import("std");

const Namespace = enum {
    buffer,
    texture,
    sampler,
};

const LogicalResource = struct {
    name: []const u8,
    namespace: Namespace,
    parameter_block: bool,
    binding: u32,
    group: u32,
    count: u32,
};

const BindingMapping = struct {
    name: []const u8,
    namespace: Namespace,
    native_binding: u32,
    logical_binding: u32,
    count: u32,
};

const Reflection = struct {
    entryPoints: []const EntryPoint = &.{},
};

const EntryPoint = struct {
    name: []const u8,
    bindings: []const ReflectedResource = &.{},
};

const ReflectedResource = struct {
    name: []const u8,
    binding: ?NativeBinding = null,
    bindings: []const NativeBinding = &.{},
};

const NativeBinding = struct {
    kind: []const u8,
    index: ?u64 = null,
    count: ?u64 = null,
    used: ?u32 = null,
};

const Attribute = struct {
    namespace: Namespace,
    binding: u32,
    number_start: usize,
    number_end: usize,
};

const Insertion = struct {
    position: usize,
    namespace: Namespace,
    binding: u32,
};

pub fn normalizeStageMsl(
    allocator: std.mem.Allocator,
    source: []const u8,
    entry: []const u8,
    reflection_json: []const u8,
    msl: []const u8,
) ![]u8 {
    var logical_resources: std.ArrayList(LogicalResource) = .empty;
    defer logical_resources.deinit(allocator);
    try parseLogicalResources(allocator, source, &logical_resources);

    var parsed = std.json.parseFromSlice(Reflection, allocator, reflection_json, .{
        .ignore_unknown_fields = true,
    }) catch return error.MalformedMetalBindingReflection;
    defer parsed.deinit();

    const reflected_entry = try findEntryPoint(parsed.value.entryPoints, entry);
    var mappings: std.ArrayList(BindingMapping) = .empty;
    defer mappings.deinit(allocator);
    try buildMappings(allocator, logical_resources.items, reflected_entry, &mappings);
    if (mappings.items.len == 0) return allocator.dupe(u8, msl);

    const parameter_range = findEntryParameterRange(msl, entry) orelse {
        return error.MissingMetalEntryPoint;
    };
    const parameters = msl[parameter_range[0]..parameter_range[1]];

    var attributes: std.ArrayList(Attribute) = .empty;
    defer attributes.deinit(allocator);
    try parseAttributes(allocator, parameters, &attributes);
    var insertions: std.ArrayList(Insertion) = .empty;
    defer insertions.deinit(allocator);
    try resolveMissingArrayAttributes(
        allocator,
        mappings.items,
        parameters,
        attributes.items,
        &insertions,
    );
    try validateAttributes(allocator, mappings.items, attributes.items, insertions.items);

    var normalized: std.ArrayList(u8) = .empty;
    errdefer normalized.deinit(allocator);
    try normalized.appendSlice(allocator, msl[0..parameter_range[0]]);

    var cursor: usize = 0;
    var attribute_index: usize = 0;
    var insertion_index: usize = 0;
    while (attribute_index < attributes.items.len or insertion_index < insertions.items.len) {
        const use_insertion = insertion_index < insertions.items.len and
            (attribute_index >= attributes.items.len or
                insertions.items[insertion_index].position < attributes.items[attribute_index].number_start);
        if (use_insertion) {
            const insertion = insertions.items[insertion_index];
            try normalized.appendSlice(allocator, parameters[cursor..insertion.position]);
            try normalized.print(
                allocator,
                " [[{s}({})]]",
                .{ @tagName(insertion.namespace), insertion.binding },
            );
            cursor = insertion.position;
            insertion_index += 1;
        } else {
            const attribute = attributes.items[attribute_index];
            try normalized.appendSlice(allocator, parameters[cursor..attribute.number_start]);
            const binding = mappedBinding(mappings.items, attribute.namespace, attribute.binding) orelse attribute.binding;
            try normalized.print(allocator, "{}", .{binding});
            cursor = attribute.number_end;
            attribute_index += 1;
        }
    }
    try normalized.appendSlice(allocator, parameters[cursor..]);
    try normalized.appendSlice(allocator, msl[parameter_range[1]..]);
    return normalized.toOwnedSlice(allocator);
}

fn findEntryPoint(entry_points: []const EntryPoint, entry: []const u8) !EntryPoint {
    var result: ?EntryPoint = null;
    for (entry_points) |candidate| {
        if (!std.mem.eql(u8, candidate.name, entry)) continue;
        if (result != null) return error.ConflictingMetalEntryPointReflection;
        result = candidate;
    }
    return result orelse error.MissingMetalEntryPointReflection;
}

fn buildMappings(
    allocator: std.mem.Allocator,
    logical_resources: []const LogicalResource,
    entry: EntryPoint,
    mappings: *std.ArrayList(BindingMapping),
) !void {
    for (entry.bindings) |reflected| {
        const native = try usedNativeBinding(reflected) orelse continue;
        const logical = findLogicalResource(logical_resources, reflected.name) orelse {
            return error.MissingMetalSourceBinding;
        };
        // Ordinary vkmtl Metal bind groups currently expose one unflattened
        // resource namespace. Resource tables are different: the outer
        // ParameterBlock buffer is bound at its pipeline-layout/group slot.
        if (!logical.parameter_block and logical.group != 0) {
            return error.UnsupportedMetalBindingGroup;
        }
        if (logical.parameter_block and (logical.binding != 0 or logical.count != 1)) {
            return error.UnsupportedMetalResourceTableBinding;
        }
        if (!reflectionKindCompatible(logical.namespace, native.kind)) {
            return error.MetalBindingNamespaceMismatch;
        }
        const native_index = try checkedIndex(native.index orelse return error.MalformedMetalBindingReflection);
        const native_count = try checkedCount(native.count orelse 1);
        if (native_count != logical.count) return error.MetalBindingArrayCountMismatch;
        _ = try checkedRangeEnd(native_index, logical.count);
        _ = try checkedRangeEnd(logical.binding, logical.count);

        const mapping = BindingMapping{
            .name = logical.name,
            .namespace = logical.namespace,
            .native_binding = native_index,
            .logical_binding = if (logical.parameter_block) logical.group else logical.binding,
            .count = logical.count,
        };
        for (mappings.items) |existing| {
            if (existing.namespace != mapping.namespace) continue;
            if (rangesOverlap(existing.native_binding, existing.count, mapping.native_binding, mapping.count)) {
                if (sameMapping(existing, mapping)) break;
                return error.ConflictingMetalNativeBinding;
            }
            if (rangesOverlap(existing.logical_binding, existing.count, mapping.logical_binding, mapping.count)) {
                return error.ConflictingMetalLogicalBinding;
            }
        } else {
            try mappings.append(allocator, mapping);
        }
    }
}

fn usedNativeBinding(resource: ReflectedResource) !?NativeBinding {
    var result: ?NativeBinding = null;
    if (resource.binding) |binding| try considerNativeBinding(binding, &result);
    for (resource.bindings) |binding| try considerNativeBinding(binding, &result);
    return result;
}

fn considerNativeBinding(binding: NativeBinding, result: *?NativeBinding) !void {
    const used = binding.used orelse return error.MalformedMetalBindingReflection;
    if (used > 1) return error.MalformedMetalBindingReflection;
    if (used == 0) return;
    // Slang can emit an additional used binding with count zero for structured
    // buffers. It is metadata, not a Metal entry-point resource range.
    if (binding.count == 0) return;
    // Entry-point reflection also reports non-resource bindings such as
    // specialization constants. They have no Metal buffer/texture/sampler
    // attribute to normalize.
    if (!isMetalResourceReflectionKind(binding.kind)) return;
    if (binding.index == null) return error.MalformedMetalBindingReflection;
    if (result.*) |existing| {
        if (existing.index != binding.index or
            existing.count != binding.count or
            !std.mem.eql(u8, existing.kind, binding.kind))
        {
            return error.ConflictingMetalNativeBinding;
        }
        return;
    }
    result.* = binding;
}

fn isMetalResourceReflectionKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "constantBuffer") or
        std.mem.eql(u8, kind, "shaderResource") or
        std.mem.eql(u8, kind, "unorderedAccess") or
        std.mem.eql(u8, kind, "samplerState");
}

fn findLogicalResource(resources: []const LogicalResource, name: []const u8) ?LogicalResource {
    for (resources) |resource| {
        if (std.mem.eql(u8, resource.name, name)) return resource;
    }
    return null;
}

fn reflectionKindCompatible(namespace: Namespace, kind: []const u8) bool {
    return switch (namespace) {
        .buffer => std.mem.eql(u8, kind, "constantBuffer") or
            std.mem.eql(u8, kind, "shaderResource") or
            std.mem.eql(u8, kind, "unorderedAccess"),
        .texture => std.mem.eql(u8, kind, "shaderResource") or
            std.mem.eql(u8, kind, "unorderedAccess"),
        .sampler => std.mem.eql(u8, kind, "samplerState"),
    };
}

fn parseLogicalResources(
    allocator: std.mem.Allocator,
    source: []const u8,
    resources: *std.ArrayList(LogicalResource),
) !void {
    const marker = "vk::binding";
    var search_start: usize = 0;
    while (std.mem.indexOfPos(u8, source, search_start, marker)) |marker_start| {
        const open = std.mem.indexOfScalarPos(u8, source, marker_start + marker.len, '(') orelse {
            return error.MalformedMetalSourceBinding;
        };
        const close = std.mem.indexOfScalarPos(u8, source, open + 1, ')') orelse {
            return error.MalformedMetalSourceBinding;
        };
        const binding = try parseSourceBinding(source[open + 1 .. close]);
        const annotation_end = std.mem.indexOfPos(u8, source, close + 1, "]]") orelse {
            return error.MalformedMetalSourceBinding;
        };
        var declaration_start = try skipTriviaAndAnnotations(source, annotation_end + 2);
        const semicolon = std.mem.indexOfScalarPos(u8, source, declaration_start, ';') orelse {
            return error.MissingMetalSourceResource;
        };
        const declaration = std.mem.trim(u8, source[declaration_start..semicolon], " \t\r\n");
        if (declaration.len == 0) return error.MissingMetalSourceResource;
        const parsed_declaration = parseResourceDeclaration(declaration) orelse {
            return error.UnsupportedMetalSourceResource;
        };
        const count = try parseResourceArrayCount(declaration, parsed_declaration.name_end);
        _ = try checkedRangeEnd(binding[0], count);

        const resource = LogicalResource{
            .name = parsed_declaration.name,
            .namespace = parsed_declaration.namespace,
            .parameter_block = parsed_declaration.parameter_block,
            .binding = binding[0],
            .group = binding[1],
            .count = count,
        };
        for (resources.items) |existing| {
            if (std.mem.eql(u8, existing.name, resource.name)) {
                return error.ConflictingMetalSourceBinding;
            }
        }
        try resources.append(allocator, resource);
        declaration_start = semicolon + 1;
        search_start = declaration_start;
    }
}

fn parseSourceBinding(contents: []const u8) ![2]u32 {
    const comma = std.mem.indexOfScalar(u8, contents, ',') orelse {
        return error.MalformedMetalSourceBinding;
    };
    return .{
        try parseSourceIndex(contents[0..comma]),
        try parseSourceIndex(contents[comma + 1 ..]),
    };
}

fn parseSourceIndex(text: []const u8) !u32 {
    const value = std.fmt.parseInt(u64, std.mem.trim(u8, text, " \t\r\n"), 10) catch {
        return error.MalformedMetalSourceBinding;
    };
    return checkedIndex(value);
}

fn skipTriviaAndAnnotations(source: []const u8, start: usize) !usize {
    var index = start;
    while (true) {
        while (index < source.len and std.ascii.isWhitespace(source[index])) index += 1;
        if (index + 1 < source.len and source[index] == '/' and source[index + 1] == '/') {
            index = std.mem.indexOfScalarPos(u8, source, index + 2, '\n') orelse source.len;
            continue;
        }
        if (index + 1 < source.len and source[index] == '/' and source[index + 1] == '*') {
            const comment_end = std.mem.indexOfPos(u8, source, index + 2, "*/") orelse {
                return error.MalformedMetalSourceBinding;
            };
            index = comment_end + 2;
            continue;
        }
        if (index + 1 < source.len and source[index] == '[' and source[index + 1] == '[') {
            const annotation_end = std.mem.indexOfPos(u8, source, index + 2, "]]") orelse {
                return error.MalformedMetalSourceBinding;
            };
            index = annotation_end + 2;
            continue;
        }
        return index;
    }
}

fn parseResourceDeclaration(declaration: []const u8) ?struct {
    namespace: Namespace,
    parameter_block: bool,
    name: []const u8,
    name_end: usize,
} {
    var tokens = std.mem.tokenizeAny(u8, declaration, " \t\r\n");
    var type_token: ?[]const u8 = null;
    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, "globallycoherent") or
            std.mem.eql(u8, token, "static") or
            std.mem.eql(u8, token, "const"))
        {
            continue;
        }
        type_token = token;
        break;
    }
    const resource_type = type_token orelse return null;
    const namespace = namespaceForType(resource_type) orelse return null;
    const parameter_block = std.mem.startsWith(u8, resource_type, "ParameterBlock<");

    const declaration_end = std.mem.indexOfScalar(u8, declaration, ':') orelse declaration.len;
    var name: ?[]const u8 = null;
    var name_end: usize = 0;
    var index: usize = 0;
    while (index < declaration_end) {
        if (!isIdentifierStart(declaration[index])) {
            index += 1;
            continue;
        }
        const identifier_start = index;
        index += 1;
        while (index < declaration_end and isIdentifierByte(declaration[index])) index += 1;
        name = declaration[identifier_start..index];
        name_end = index;
    }
    return .{
        .namespace = namespace,
        .parameter_block = parameter_block,
        .name = name orelse return null,
        .name_end = name_end,
    };
}

fn namespaceForType(type_token: []const u8) ?Namespace {
    if (std.mem.startsWith(u8, type_token, "ConstantBuffer<") or
        std.mem.startsWith(u8, type_token, "ParameterBlock<") or
        std.mem.startsWith(u8, type_token, "StructuredBuffer<") or
        std.mem.startsWith(u8, type_token, "RWStructuredBuffer<") or
        std.mem.startsWith(u8, type_token, "AppendStructuredBuffer<") or
        std.mem.startsWith(u8, type_token, "ConsumeStructuredBuffer<") or
        std.mem.eql(u8, type_token, "ByteAddressBuffer") or
        std.mem.eql(u8, type_token, "RWByteAddressBuffer"))
    {
        return .buffer;
    }
    if (std.mem.startsWith(u8, type_token, "Texture") or
        std.mem.startsWith(u8, type_token, "RWTexture"))
    {
        return .texture;
    }
    if (std.mem.eql(u8, type_token, "SamplerState") or
        std.mem.eql(u8, type_token, "SamplerComparisonState"))
    {
        return .sampler;
    }
    return null;
}

fn parseResourceArrayCount(declaration: []const u8, name_end: usize) !u32 {
    var index = name_end;
    while (index < declaration.len and std.ascii.isWhitespace(declaration[index])) index += 1;
    if (index >= declaration.len or declaration[index] != '[') return 1;
    const close = std.mem.indexOfScalarPos(u8, declaration, index + 1, ']') orelse {
        return error.MalformedMetalSourceBinding;
    };
    const count = std.fmt.parseInt(u64, std.mem.trim(u8, declaration[index + 1 .. close], " \t\r\n"), 10) catch {
        return error.UnsupportedMetalBindingArray;
    };
    if (count == 0) return error.UnsupportedMetalBindingArray;
    return checkedIndex(count);
}

fn findEntryParameterRange(msl: []const u8, entry: []const u8) ?[2]usize {
    var search_start: usize = 0;
    var result: ?[2]usize = null;
    while (std.mem.indexOfPos(u8, msl, search_start, entry)) |entry_start| {
        const entry_end = entry_start + entry.len;
        const before_ok = entry_start == 0 or !isIdentifierByte(msl[entry_start - 1]);
        const after_ok = entry_end >= msl.len or !isIdentifierByte(msl[entry_end]);
        search_start = entry_end;
        if (!before_ok or !after_ok) continue;
        var open = entry_end;
        while (open < msl.len and std.ascii.isWhitespace(msl[open])) open += 1;
        if (open >= msl.len or msl[open] != '(') continue;
        const close = matchingParen(msl, open) orelse continue;
        var body = close + 1;
        while (body < msl.len and std.ascii.isWhitespace(msl[body])) body += 1;
        if (body >= msl.len or msl[body] != '{') continue;
        if (result != null) return null;
        result = .{ open + 1, close };
    }
    return result;
}

fn matchingParen(text: []const u8, open: usize) ?usize {
    var depth: usize = 0;
    var index = open;
    while (index < text.len) : (index += 1) {
        switch (text[index]) {
            '(' => depth += 1,
            ')' => {
                if (depth == 0) return null;
                depth -= 1;
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn parseAttributes(
    allocator: std.mem.Allocator,
    parameters: []const u8,
    attributes: *std.ArrayList(Attribute),
) !void {
    var search_start: usize = 0;
    while (nextAttribute(parameters, search_start)) |found| {
        const number_end = std.mem.indexOfScalarPos(u8, parameters, found.number_start, ')') orelse {
            return error.MalformedMetalBindingAttribute;
        };
        const binding = std.fmt.parseInt(
            u64,
            std.mem.trim(u8, parameters[found.number_start..number_end], " \t\r\n"),
            10,
        ) catch return error.MalformedMetalBindingAttribute;
        try attributes.append(allocator, .{
            .namespace = found.namespace,
            .binding = try checkedIndex(binding),
            .number_start = found.number_start,
            .number_end = number_end,
        });
        search_start = number_end + 1;
    }
}

fn nextAttribute(parameters: []const u8, search_start: usize) ?struct {
    namespace: Namespace,
    number_start: usize,
} {
    var best_position: ?usize = null;
    var best_namespace: Namespace = undefined;
    var best_marker_len: usize = 0;
    inline for (.{
        .{ "[[buffer(", Namespace.buffer },
        .{ "[[texture(", Namespace.texture },
        .{ "[[sampler(", Namespace.sampler },
    }) |candidate| {
        if (std.mem.indexOfPos(u8, parameters, search_start, candidate[0])) |position| {
            if (best_position == null or position < best_position.?) {
                best_position = position;
                best_namespace = candidate[1];
                best_marker_len = candidate[0].len;
            }
        }
    }
    const position = best_position orelse return null;
    return .{
        .namespace = best_namespace,
        .number_start = position + best_marker_len,
    };
}

fn resolveMissingArrayAttributes(
    allocator: std.mem.Allocator,
    mappings: []const BindingMapping,
    parameters: []const u8,
    attributes: []const Attribute,
    insertions: *std.ArrayList(Insertion),
) !void {
    for (mappings) |mapping| {
        var matches: usize = 0;
        for (attributes) |attribute| {
            if (attribute.namespace == mapping.namespace and attribute.binding == mapping.native_binding) {
                matches += 1;
            }
        }
        if (matches == 0) {
            if (mapping.count == 1) return error.MissingMetalBindingAttribute;
            const position = try findArrayParameterInsertion(parameters, mapping);
            try appendInsertionSorted(allocator, insertions, .{
                .position = position,
                .namespace = mapping.namespace,
                .binding = mapping.logical_binding,
            });
        }
        if (matches > 1) return error.ConflictingMetalBindingAttribute;
    }
}

fn findArrayParameterInsertion(parameters: []const u8, mapping: BindingMapping) !usize {
    var result: ?usize = null;
    var segment_start: usize = 0;
    var angle_depth: usize = 0;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    var index: usize = 0;
    while (index <= parameters.len) : (index += 1) {
        const at_end = index == parameters.len;
        const byte = if (at_end) 0 else parameters[index];
        if (at_end or (byte == ',' and angle_depth == 0 and paren_depth == 0 and bracket_depth == 0)) {
            const segment_end = trimEndIndex(parameters, segment_start, index);
            const segment = parameters[segment_start..segment_end];
            if (parameterContainsGeneratedName(segment, mapping.name)) {
                if (!parameterIsResourceArray(segment, mapping.namespace)) {
                    return error.MetalBindingArrayParameterMismatch;
                }
                if (nextAttribute(segment, 0) != null) {
                    return error.ConflictingMetalBindingAttribute;
                }
                if (result != null) return error.ConflictingMetalBindingAttribute;
                result = segment_end;
            }
            segment_start = index + 1;
            continue;
        }
        switch (byte) {
            '<' => angle_depth += 1,
            '>' => {
                if (angle_depth == 0) return error.MalformedMetalEntryPoint;
                angle_depth -= 1;
            },
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return error.MalformedMetalEntryPoint;
                paren_depth -= 1;
            },
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth == 0) return error.MalformedMetalEntryPoint;
                bracket_depth -= 1;
            },
            else => {},
        }
    }
    if (angle_depth != 0 or paren_depth != 0 or bracket_depth != 0) {
        return error.MalformedMetalEntryPoint;
    }
    return result orelse error.MissingMetalBindingAttribute;
}

fn trimEndIndex(text: []const u8, start: usize, end: usize) usize {
    var result = end;
    while (result > start and std.ascii.isWhitespace(text[result - 1])) result -= 1;
    return result;
}

fn parameterContainsGeneratedName(parameter: []const u8, source_name: []const u8) bool {
    var index: usize = 0;
    while (index < parameter.len) {
        if (!isIdentifierStart(parameter[index])) {
            index += 1;
            continue;
        }
        const start = index;
        index += 1;
        while (index < parameter.len and isIdentifierByte(parameter[index])) index += 1;
        const identifier = parameter[start..index];
        if (std.mem.eql(u8, identifier, source_name)) return true;
        if (identifier.len <= source_name.len + 1 or
            !std.mem.startsWith(u8, identifier, source_name) or
            identifier[source_name.len] != '_')
        {
            continue;
        }
        const suffix = identifier[source_name.len + 1 ..];
        var all_digits = suffix.len != 0;
        for (suffix) |digit| all_digits = all_digits and std.ascii.isDigit(digit);
        if (all_digits) return true;
    }
    return false;
}

fn parameterIsResourceArray(parameter: []const u8, namespace: Namespace) bool {
    if (std.mem.indexOf(u8, parameter, "array<") == null) return false;
    return switch (namespace) {
        .buffer => std.mem.indexOf(u8, parameter, " device*") != null or
            std.mem.indexOf(u8, parameter, " constant*") != null,
        .texture => std.mem.indexOf(u8, parameter, "texture") != null,
        .sampler => std.mem.indexOf(u8, parameter, "sampler") != null,
    };
}

fn appendInsertionSorted(
    allocator: std.mem.Allocator,
    insertions: *std.ArrayList(Insertion),
    insertion: Insertion,
) !void {
    var index: usize = 0;
    while (index < insertions.items.len and insertions.items[index].position < insertion.position) {
        index += 1;
    }
    if (index < insertions.items.len and insertions.items[index].position == insertion.position) {
        return error.ConflictingMetalBindingAttribute;
    }
    try insertions.insert(allocator, index, insertion);
}

fn validateAttributes(
    allocator: std.mem.Allocator,
    mappings: []const BindingMapping,
    attributes: []const Attribute,
    insertions: []const Insertion,
) !void {
    const ResolvedBinding = struct {
        namespace: Namespace,
        binding: u32,
        count: u32,
    };
    var resolved: std.ArrayList(ResolvedBinding) = .empty;
    defer resolved.deinit(allocator);
    try resolved.ensureTotalCapacity(allocator, attributes.len + insertions.len);

    for (attributes) |attribute| {
        const mapping = mappingForNative(mappings, attribute.namespace, attribute.binding);
        resolved.appendAssumeCapacity(.{
            .namespace = attribute.namespace,
            .binding = if (mapping) |value| value.logical_binding else attribute.binding,
            .count = if (mapping) |value| value.count else 1,
        });
    }
    for (insertions) |insertion| {
        const mapping = mappingForLogical(mappings, insertion.namespace, insertion.binding) orelse {
            return error.MissingMetalSourceBinding;
        };
        resolved.appendAssumeCapacity(.{
            .namespace = insertion.namespace,
            .binding = insertion.binding,
            .count = mapping.count,
        });
    }

    for (resolved.items, 0..) |binding, index| {
        _ = try checkedRangeEnd(binding.binding, binding.count);
        for (resolved.items[index + 1 ..]) |other| {
            if (binding.namespace != other.namespace) continue;
            if (rangesOverlap(binding.binding, binding.count, other.binding, other.count)) {
                return error.ConflictingMetalLogicalBinding;
            }
        }
    }
}

fn mappingForNative(
    mappings: []const BindingMapping,
    namespace: Namespace,
    binding: u32,
) ?BindingMapping {
    for (mappings) |mapping| {
        if (mapping.namespace == namespace and mapping.native_binding == binding) return mapping;
    }
    return null;
}

fn mappingForLogical(
    mappings: []const BindingMapping,
    namespace: Namespace,
    binding: u32,
) ?BindingMapping {
    for (mappings) |mapping| {
        if (mapping.namespace == namespace and mapping.logical_binding == binding) return mapping;
    }
    return null;
}

fn mappedBinding(
    mappings: []const BindingMapping,
    namespace: Namespace,
    binding: u32,
) ?u32 {
    const mapping = mappingForNative(mappings, namespace, binding) orelse return null;
    return mapping.logical_binding;
}

fn checkedIndex(value: u64) !u32 {
    if (value > std.math.maxInt(u32)) return error.MetalBindingIndexOutOfRange;
    return @intCast(value);
}

fn checkedCount(value: u64) !u32 {
    if (value == 0 or value > std.math.maxInt(u32)) {
        return error.MetalBindingIndexOutOfRange;
    }
    return @intCast(value);
}

fn checkedRangeEnd(base: u32, count: u32) !u32 {
    if (count == 0) return error.MetalBindingIndexOutOfRange;
    return std.math.add(u32, base, count - 1) catch error.MetalBindingIndexOutOfRange;
}

fn rangesOverlap(a_base: u32, a_count: u32, b_base: u32, b_count: u32) bool {
    const a_end = checkedRangeEnd(a_base, a_count) catch return true;
    const b_end = checkedRangeEnd(b_base, b_count) catch return true;
    return a_base <= b_end and b_base <= a_end;
}

fn sameMapping(a: BindingMapping, b: BindingMapping) bool {
    return a.namespace == b.namespace and
        a.native_binding == b.native_binding and
        a.logical_binding == b.logical_binding and
        a.count == b.count and
        std.mem.eql(u8, a.name, b.name);
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

test "normalizes temporal and atrous Metal texture bindings" {
    const source =
        \\[[vk::binding(0, 0)]]
        \\ConstantBuffer<float4> temporal_data : register(b0, space0);
        \\[[vk::binding(1, 0)]]
        \\Texture2D<float4> temporal_current : register(t1, space0);
        \\[[vk::binding(2, 0)]]
        \\Texture2D<float4> temporal_gbuffer : register(t2, space0);
        \\[[vk::binding(5, 0)]]
        \\SamplerState temporal_sampler : register(s5, space0);
        \\[[vk::binding(6, 0)]]
        \\[[vk::image_format("rgba16f")]]
        \\RWTexture2D<float4> temporal_output : register(u6, space0);
        \\[[vk::binding(7, 0)]]
        \\ConstantBuffer<float4> atrous_data : register(b7, space0);
        \\[[vk::binding(8, 0)]]
        \\Texture2D<float4> atrous_input : register(t8, space0);
        \\[[vk::binding(9, 0)]]
        \\Texture2D<float4> atrous_gbuffer : register(t9, space0);
        \\[[vk::binding(11, 0)]]
        \\RWTexture2D<float4> atrous_output : register(u11, space0);
    ;
    const temporal_reflection =
        \\{"entryPoints":[{"name":"temporal_cs","bindings":[
        \\{"name":"temporal_data","binding":{"kind":"constantBuffer","index":0,"used":1}},
        \\{"name":"temporal_current","binding":{"kind":"shaderResource","index":1,"used":1}},
        \\{"name":"temporal_gbuffer","binding":{"kind":"shaderResource","index":2,"used":1}},
        \\{"name":"temporal_sampler","binding":{"kind":"samplerState","index":5,"used":1}},
        \\{"name":"temporal_output","bindings":[{"kind":"shaderResource","index":0,"used":1},{"kind":"unorderedAccess","index":0,"used":0}]},
        \\{"name":"atrous_output","bindings":[{"kind":"shaderResource","index":5,"used":0},{"kind":"unorderedAccess","index":0,"used":0}]}
        \\]}]}
    ;
    const temporal_msl =
        "[[kernel]] void temporal_cs(uint3 tid [[thread_position_in_grid]], " ++
        "texture2d<float, access::read_write> temporal_output [[texture(0)]], " ++
        "texture2d<float> temporal_gbuffer [[texture(2)]], " ++
        "texture2d<float> temporal_current [[texture(1)]], " ++
        "float4 constant* temporal_data [[buffer(0)]], " ++
        "sampler temporal_sampler [[sampler(5)]]) { return; }\n";
    const normalized_temporal = try normalizeStageMsl(
        std.testing.allocator,
        source,
        "temporal_cs",
        temporal_reflection,
        temporal_msl,
    );
    defer std.testing.allocator.free(normalized_temporal);
    try std.testing.expect(std.mem.indexOf(u8, normalized_temporal, "temporal_output [[texture(6)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized_temporal, "tid [[thread_position_in_grid]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized_temporal, "temporal_data [[buffer(0)]]") != null);

    const atrous_reflection =
        \\{"entryPoints":[{"name":"atrous_cs","bindings":[
        \\{"name":"atrous_data","binding":{"kind":"constantBuffer","index":7,"used":1}},
        \\{"name":"atrous_input","binding":{"kind":"shaderResource","index":8,"used":1}},
        \\{"name":"atrous_gbuffer","binding":{"kind":"shaderResource","index":9,"used":1}},
        \\{"name":"atrous_output","bindings":[{"kind":"shaderResource","index":5,"used":1},{"kind":"unorderedAccess","index":0,"used":0}]}
        \\]}]}
    ;
    const atrous_msl =
        "[[kernel]] void atrous_cs(uint3 tid [[thread_position_in_grid]], " ++
        "texture2d<float, access::read_write> atrous_output [[texture(5)]], " ++
        "texture2d<float> atrous_gbuffer [[texture(9)]], " ++
        "texture2d<float> atrous_input [[texture(8)]], " ++
        "float4 constant* atrous_data [[buffer(7)]]) { return; }\n";
    const normalized_atrous = try normalizeStageMsl(
        std.testing.allocator,
        source,
        "atrous_cs",
        atrous_reflection,
        atrous_msl,
    );
    defer std.testing.allocator.free(normalized_atrous);
    try std.testing.expect(std.mem.indexOf(u8, normalized_atrous, "atrous_output [[texture(11)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized_atrous, "tid [[thread_position_in_grid]]") != null);
}

test "normalization is one pass and preserves resource namespaces" {
    const source =
        \\[[vk::binding(6, 0)]]
        \\RWTexture2D<float4> first_output : register(u6, space0);
        \\[[vk::binding(11, 0)]]
        \\RWTexture2D<float4> second_output : register(u11, space0);
        \\[[vk::binding(9, 0)]]
        \\RWStructuredBuffer<uint> output_values : register(u9, space0);
    ;
    const reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"first_output","binding":{"kind":"shaderResource","index":0,"used":1}},
        \\{"name":"second_output","binding":{"kind":"shaderResource","index":6,"used":1}},
        \\{"name":"output_values","binding":{"kind":"constantBuffer","index":0,"used":1}}
        \\]}]}
    ;
    const msl = "[[kernel]] void cs_main(texture2d<float> a [[texture(0)]], texture2d<float> b [[texture(6)]], uint device* c [[buffer(0)]]) { return; }";
    const normalized = try normalizeStageMsl(std.testing.allocator, source, "cs_main", reflection, msl);
    defer std.testing.allocator.free(normalized);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "a [[texture(6)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "b [[texture(11)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "c [[buffer(9)]]") != null);
}

test "resource arrays normalize their Metal base binding" {
    const source =
        \\[[vk::binding(6, 0)]]
        \\Texture2D<float4> material_textures[4] : register(t6, space0);
    ;
    const reflection =
        \\{"entryPoints":[{"name":"fs_main","bindings":[
        \\{"name":"material_textures","binding":{"kind":"shaderResource","index":0,"count":4,"used":1}}
        \\]}]}
    ;
    const msl = "[[fragment]] float4 fs_main(array<texture2d<float>, 4> values [[texture(0)]], float4 position [[position]]) { return position; }";
    const normalized = try normalizeStageMsl(std.testing.allocator, source, "fs_main", reflection, msl);
    defer std.testing.allocator.free(normalized);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "values [[texture(6)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "position [[position]]") != null);
}

test "missing Slang attributes are restored for resource arrays" {
    const source =
        \\[[vk::binding(5, 0)]]
        \\Texture2D<float4> textures[3] : register(t2, space0);
        \\[[vk::binding(9, 0)]]
        \\SamplerState samplers[2] : register(s4, space0);
        \\[[vk::binding(12, 0)]]
        \\RWStructuredBuffer<uint> outputs[2] : register(u10, space0);
        \\[[vk::binding(15, 0)]]
        \\ConstantBuffer<float4> constants[2] : register(b6, space0);
    ;
    const reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"textures","binding":{"kind":"shaderResource","index":2,"count":3,"used":1}},
        \\{"name":"samplers","binding":{"kind":"samplerState","index":4,"count":2,"used":1}},
        \\{"name":"outputs","bindings":[{"kind":"constantBuffer","index":10,"count":2,"used":1},{"kind":"unorderedAccess","index":0,"count":0,"used":1}]},
        \\{"name":"constants","binding":{"kind":"constantBuffer","index":6,"count":2,"used":1}}
        \\]}]}
    ;
    const msl =
        "[[kernel]] void cs_main(uint3 tid [[thread_position_in_grid]], " ++
        "array<uint device*, int(2)> outputs_1, " ++
        "array<texture2d<float, access::sample>, int(3)> textures_1, " ++
        "array<sampler, int(2)> samplers_1, " ++
        "array<float4 constant*, int(2)> constants_1) { return; }";
    const normalized = try normalizeStageMsl(std.testing.allocator, source, "cs_main", reflection, msl);
    defer std.testing.allocator.free(normalized);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "outputs_1 [[buffer(12)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "textures_1 [[texture(5)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "samplers_1 [[sampler(9)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "constants_1 [[buffer(15)]]") != null);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "tid [[thread_position_in_grid]]") != null);
}

test "normalization reports missing conflicts and out of range bindings" {
    const source =
        \\[[vk::binding(6, 0)]]
        \\Texture2D<float4> first_texture : register(t6, space0);
        \\[[vk::binding(7, 0)]]
        \\Texture2D<float4> second_texture : register(t7, space0);
    ;
    const missing_source_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"unknown_texture","binding":{"kind":"shaderResource","index":0,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.MissingMetalSourceBinding,
        normalizeStageMsl(std.testing.allocator, source, "cs_main", missing_source_reflection, "[[kernel]] void cs_main() {}"),
    );

    const conflict_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"first_texture","binding":{"kind":"shaderResource","index":0,"used":1}},
        \\{"name":"second_texture","binding":{"kind":"shaderResource","index":0,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.ConflictingMetalNativeBinding,
        normalizeStageMsl(std.testing.allocator, source, "cs_main", conflict_reflection, "[[kernel]] void cs_main(texture2d<float> value [[texture(0)]]) {}"),
    );

    const missing_attribute_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"first_texture","binding":{"kind":"shaderResource","index":0,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.MissingMetalBindingAttribute,
        normalizeStageMsl(std.testing.allocator, source, "cs_main", missing_attribute_reflection, "[[kernel]] void cs_main(texture2d<float> value [[texture(1)]]) {}"),
    );

    const out_of_range_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"first_texture","binding":{"kind":"shaderResource","index":4294967296,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.MetalBindingIndexOutOfRange,
        normalizeStageMsl(std.testing.allocator, source, "cs_main", out_of_range_reflection, "[[kernel]] void cs_main(texture2d<float> value [[texture(0)]]) {}"),
    );

    const nonzero_group_source =
        \\[[vk::binding(6, 1)]]
        \\Texture2D<float4> first_texture : register(t6, space1);
    ;
    const nonzero_group_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"first_texture","binding":{"kind":"shaderResource","index":0,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.UnsupportedMetalBindingGroup,
        normalizeStageMsl(std.testing.allocator, nonzero_group_source, "cs_main", nonzero_group_reflection, "[[kernel]] void cs_main(texture2d<float> value [[texture(0)]]) {}"),
    );

    const count_mismatch_source =
        \\[[vk::binding(6, 0)]]
        \\Texture2D<float4> textures[2] : register(t6, space0);
    ;
    const count_mismatch_reflection =
        \\{"entryPoints":[{"name":"cs_main","bindings":[
        \\{"name":"textures","binding":{"kind":"shaderResource","index":0,"count":3,"used":1}}
        \\]}]}
    ;
    try std.testing.expectError(
        error.MetalBindingArrayCountMismatch,
        normalizeStageMsl(std.testing.allocator, count_mismatch_source, "cs_main", count_mismatch_reflection, "[[kernel]] void cs_main(array<texture2d<float>, int(2)> textures_0) {}"),
    );
}

test "non-resource entry bindings are ignored" {
    const reflection =
        \\{"entryPoints":[{"name":"fs_main","bindings":[
        \\{"name":"color_scale","binding":{"kind":"specializationConstant","index":7,"used":1}}
        \\]}]}
    ;
    const msl = "[[fragment]] float4 fs_main(float4 position [[position]]) { return position; }";
    const normalized = try normalizeStageMsl(std.testing.allocator, "", "fs_main", reflection, msl);
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings(msl, normalized);
}

test "ParameterBlock uses its resource table group as the Metal buffer slot" {
    const source =
        \\struct Table { Texture2D<float4> textures[4]; };
        \\[[vk::binding(0, 2)]]
        \\ParameterBlock<Table> texture_table : register(b0, space2);
    ;
    const reflection =
        \\{"entryPoints":[{"name":"fs_main","bindings":[
        \\{"name":"texture_table","binding":{"kind":"constantBuffer","index":0,"used":1}}
        \\]}]}
    ;
    const msl = "[[fragment]] float4 fs_main(Table constant* texture_table_0 [[buffer(0)]]) { return 0; }";
    const normalized = try normalizeStageMsl(std.testing.allocator, source, "fs_main", reflection, msl);
    defer std.testing.allocator.free(normalized);
    try std.testing.expect(std.mem.indexOf(u8, normalized, "texture_table_0 [[buffer(2)]]") != null);
}
