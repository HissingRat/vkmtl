#!/usr/bin/env bash
set -euo pipefail

backend="${1:-}"
artifact_dir="${2:-artifacts/gpu-smoke}"

if [[ "$backend" != "metal" && "$backend" != "vulkan" ]]; then
    echo "usage: run_gpu_smoke.sh <metal|vulkan> [artifact-dir]" >&2
    exit 2
fi

mkdir -p "$artifact_dir"
build_args=()
export VKMTL_BACKEND="$backend"

if [[ "$backend" == "vulkan" ]]; then
    build_args+=("-Dvulkan")
    if [[ -n "${VKMTL_VULKAN_LOADER_DIR:-}" ]]; then
        build_args+=("-Dvulkan-loader-dir=${VKMTL_VULKAN_LOADER_DIR}")
    fi
    if [[ -n "${VKMTL_VULKAN_ICD:-}" ]]; then
        build_args+=("-Dvulkan-icd=${VKMTL_VULKAN_ICD}")
    fi
fi

{
    echo "backend=$backend"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "zig=$(zig version)"
    uname -a
    sw_vers 2>/dev/null || true
    vulkaninfo --summary 2>/dev/null || true
} >"$artifact_dir/host.txt"

failure_bundle() {
    status=$?
    trap - EXIT
    if [[ $status -ne 0 ]]; then
        {
            echo "smoke_status=failed"
            echo "exit_code=$status"
            VKMTL_BACKEND="$backend" zig build run-capability-dump "${build_args[@]}" || true
        } >"$artifact_dir/failure-capability-dump.txt" 2>&1
    fi
    exit "$status"
}
trap failure_bundle EXIT

zig build run-capability-dump "${build_args[@]}" 2>&1 | tee "$artifact_dir/capability-dump.txt"
zig build run-pixel-regression "${build_args[@]}" 2>&1 | tee "$artifact_dir/pixel-regression.txt"
if [[ "$backend" == "metal" ]]; then
    zig build run-release-readiness -- --metal-smoke --metal-pixels 2>&1 | tee "$artifact_dir/release-readiness-partial.txt"
else
    zig build run-release-readiness -- --vulkan-smoke --vulkan-pixels 2>&1 | tee "$artifact_dir/release-readiness-partial.txt"
fi

echo "smoke_status=passed" >"$artifact_dir/status.txt"
