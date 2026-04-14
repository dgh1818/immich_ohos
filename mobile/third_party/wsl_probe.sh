set -e
find /home/dgh18 /opt /usr/local /home -maxdepth 8 -path '"'"'*/openharmony/native/llvm/bin/aarch64-linux-ohos-clang'"'"' 2>/dev/null | sort -u | head -50
echo TOOLS
for cmd in cmake make pkg-config autoconf autoreconf automake patch unzip tar git ninja curl sha512sum wget; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%s=%s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '%s=MISSING\n' "$cmd"
  fi
done