#!/usr/bin/env bash
set -euo pipefail

backend="${1:-}"
iterations="${2:-120}"
artifact_dir="${3:-artifacts/gpu-soak}"

if [[ "$backend" != "metal" && "$backend" != "vulkan" ]]; then
    echo "usage: run_gpu_soak.sh <metal|vulkan> [iterations] [artifact-dir]" >&2
    exit 2
fi
if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
    echo "iterations must be a positive integer" >&2
    exit 2
fi

mkdir -p "$artifact_dir"
build_args=()
export VKMTL_BACKEND="$backend"

git_commit="unavailable"
git_worktree="unavailable"
if resolved_commit="$(git rev-parse HEAD 2>/dev/null)"; then
    git_commit="$resolved_commit"
    if [[ -z "$(git status --porcelain=v1 --untracked-files=normal 2>/dev/null)" ]]; then
        git_worktree="clean"
    else
        git_worktree="dirty"
    fi
fi

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
    echo "iterations=$iterations"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "git_commit=$git_commit"
    echo "git_worktree=$git_worktree"
    echo "zig=$(zig version)"
    uname -a
    sw_vers 2>/dev/null || true
    vulkaninfo --summary 2>/dev/null || true
} >"$artifact_dir/host.txt"

failure_bundle() {
    status=$?
    trap - EXIT
    if [[ $status -ne 0 ]]; then
        VKMTL_BACKEND="$backend" zig build run-capability-dump "${build_args[@]}" \
            >"$artifact_dir/failure-capability-dump.txt" 2>&1 || true
    fi
    exit "$status"
}
trap failure_bundle EXIT

zig build run-capability-dump "${build_args[@]}" 2>&1 | tee "$artifact_dir/capability-dump.txt"
zig build run-gpu-soak "${build_args[@]}" -- \
    "--backend=$backend" \
    "--iterations=$iterations" 2>&1 | tee "$artifact_dir/gpu-soak.txt"

echo "soak_status=passed" >"$artifact_dir/status.txt"
echo "iterations=$iterations" >>"$artifact_dir/status.txt"
