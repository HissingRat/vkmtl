const std = @import("std");
const matrix = @import("vkmtl_development_matrix");

pub fn main(init: std.process.Init) !void {
    try matrix.validatePeriod44Jobs(matrix.period44_jobs[0..]);
    try matrix.validatePeriod44FeatureExpectations(matrix.period44_feature_expectations[0..]);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("vkmtl Period 44 validation plan\n", .{});
    try stdout.print("jobs: {}\n", .{matrix.period44_jobs.len});
    for (matrix.period44_jobs) |job| {
        try stdout.print(
            "job {s}: host={s} target={s} arch={s} backend={s} device={s} execution={s} expected={s} evidence={s} release_required={} capability_dump={}\n",
            .{
                job.name,
                @tagName(job.host_os),
                @tagName(job.target_os),
                job.architecture,
                if (job.backend) |backend| @tagName(backend) else "none",
                @tagName(job.device_class),
                @tagName(job.execution),
                @tagName(job.expected_outcome),
                @tagName(job.evidence),
                job.required_for_release,
                job.attach_capability_dump,
            },
        );
        try stdout.print("  command: {s}\n", .{job.command});
    }

    try stdout.print("feature expectations: {}\n", .{matrix.period44_feature_expectations.len});
    for (matrix.period44_feature_expectations) |feature| {
        try stdout.print("feature {s}: vulkan={s} metal={s} evidence={s}\n", .{
            feature.name,
            @tagName(feature.vulkan),
            @tagName(feature.metal),
            feature.evidence,
        });
    }
    try stdout.flush();
}
