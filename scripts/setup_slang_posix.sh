set -eu

root="$1"
archive_dir="$2"
archive="$3"
stamp="$4"
slangc="$5"
url="$6"
expected_sha="$7"
tag="$8"
package_id="$9"

if [ -x "$slangc" ] && [ -f "$stamp" ]; then
    exit 0
fi

mkdir -p "$archive_dir"
tmp="$archive.tmp"
rm -f "$tmp"
echo "fetching Slang $tag for $package_id"
curl -L --fail --retry 3 --retry-delay 2 -o "$tmp" "$url"

if command -v shasum >/dev/null 2>&1; then
    actual_sha="$(shasum -a 256 "$tmp" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "$tmp" | awk '{print $1}')"
else
    echo "vkmtl needs shasum or sha256sum to verify $url" >&2
    rm -f "$tmp"
    exit 1
fi

if [ "$actual_sha" != "$expected_sha" ]; then
    echo "vkmtl Slang archive hash mismatch for $url" >&2
    echo "expected: $expected_sha" >&2
    echo "actual:   $actual_sha" >&2
    rm -f "$tmp"
    exit 1
fi

rm -rf "$root"
mkdir -p "$root"
mv "$tmp" "$archive"
unzip -q "$archive" -d "$root"
chmod +x "$slangc" 2>/dev/null || true

if [ ! -x "$slangc" ]; then
    echo "vkmtl could not find slangc at $slangc after extracting $archive" >&2
    find "$root" -maxdepth 4 -name 'slangc*' -type f >&2 || true
    exit 1
fi

"$slangc" -version >/dev/null
touch "$stamp"
