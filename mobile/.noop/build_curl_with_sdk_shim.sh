set -e
SDK_REAL="/mnt/c/Program Files/Huawei/DevEco Studio/sdk/default/openharmony"
SDK_SHIM="/tmp/ohos-sdk-shim"
rm -rf "$SDK_SHIM"
mkdir -p "$SDK_SHIM/native/llvm/bin" "$SDK_SHIM/native/build-tools/cmake/bin" "$SDK_SHIM/native/build"
ln -s "$SDK_REAL/native/sysroot" "$SDK_SHIM/native/sysroot"
ln -s "$SDK_REAL/native/build/cmake" "$SDK_SHIM/native/build/cmake"
for tool in cmake cpack ctest ninja; do
  ln -sf "$SDK_REAL/native/build-tools/cmake/bin/${tool}.exe" "$SDK_SHIM/native/build-tools/cmake/bin/${tool}"
done
ln -sf "$SDK_REAL/native/llvm/bin/clang.exe" "$SDK_SHIM/native/llvm/bin/clang"
ln -sf "$SDK_REAL/native/llvm/bin/clang++.exe" "$SDK_SHIM/native/llvm/bin/clang++"
ln -sf "$SDK_REAL/native/llvm/bin/ld.lld.exe" "$SDK_SHIM/native/llvm/bin/ld.lld"
for tool in llvm-ar llvm-as llvm-nm llvm-objcopy llvm-objdump llvm-ranlib llvm-strip; do
  ln -sf "$SDK_REAL/native/llvm/bin/${tool}.exe" "$SDK_SHIM/native/llvm/bin/${tool}"
done
ln -sf "$SDK_REAL/native/llvm/bin/aarch64-unknown-linux-ohos-clang" "$SDK_SHIM/native/llvm/bin/aarch64-linux-ohos-clang"
ln -sf "$SDK_REAL/native/llvm/bin/aarch64-unknown-linux-ohos-clang++" "$SDK_SHIM/native/llvm/bin/aarch64-linux-ohos-clang++"
ln -sf "$SDK_REAL/native/llvm/bin/armv7-unknown-linux-ohos-clang" "$SDK_SHIM/native/llvm/bin/arm-linux-ohos-clang"
ln -sf "$SDK_REAL/native/llvm/bin/armv7-unknown-linux-ohos-clang++" "$SDK_SHIM/native/llvm/bin/arm-linux-ohos-clang++"
if [ -e "$SDK_REAL/native/llvm/bin/x86_64-unknown-linux-ohos-clang" ]; then
  ln -sf "$SDK_REAL/native/llvm/bin/x86_64-unknown-linux-ohos-clang" "$SDK_SHIM/native/llvm/bin/x86_64-linux-ohos-clang"
fi
if [ -e "$SDK_REAL/native/llvm/bin/x86_64-unknown-linux-ohos-clang++" ]; then
  ln -sf "$SDK_REAL/native/llvm/bin/x86_64-unknown-linux-ohos-clang++" "$SDK_SHIM/native/llvm/bin/x86_64-linux-ohos-clang++"
fi
for tool in aarch64-linux-ohos-clang aarch64-linux-ohos-clang++ arm-linux-ohos-clang arm-linux-ohos-clang++; do
  : > "$SDK_SHIM/native/llvm/bin/${tool}.cmd"
done
export OHOS_SDK="$SDK_SHIM"
cd /mnt/f/immich_ohos/mobile/third_party/tpc_c_cplusplus/lycium
./build.sh curl