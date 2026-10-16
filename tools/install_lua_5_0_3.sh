#!/usr/bin/env sh
set -eu

install_dir=${1:-"$PWD/.cache/lua-5.0.3"}
archive="${TMPDIR:-/tmp}/lua-5.0.3.tar.gz"
source_dir="${TMPDIR:-/tmp}/lua-5.0.3"
expected_sha256="1193a61b0e08acaa6eee0eecf29709179ee49c71baebc59b682a25c3b5a45671"

if [ -x "$install_dir/bin/lua" ]; then
    "$install_dir/bin/lua" -v
    exit 0
fi

curl --fail --location --silent --show-error \
    https://www.lua.org/ftp/lua-5.0.3.tar.gz \
    --output "$archive"

echo "$expected_sha256  $archive" | sha256sum --check --status
rm -rf "$source_dir"
tar -xzf "$archive" -C "${TMPDIR:-/tmp}"
make -C "$source_dir"
mkdir -p "$install_dir"
cp -R "$source_dir/bin" "$source_dir/include" "$source_dir/lib" "$install_dir/"
"$install_dir/bin/lua" -v
