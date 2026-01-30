#include <cstdint>
#include <cstdlib>
#include <cstring>

#include <napi/native_api.h>

namespace {

napi_value MakeInt64(napi_env env, int64_t value) {
  napi_value result;
  napi_create_int64(env, value, &result);
  return result;
}

napi_value ReturnUndefined(napi_env env) {
  napi_value undefined;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value Alloc(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 1) {
    return MakeInt64(env, 0);
  }

  int64_t size = 0;
  if (napi_get_value_int64(env, args[0], &size) != napi_ok || size <= 0) {
    return MakeInt64(env, 0);
  }

  void* ptr = std::malloc(static_cast<size_t>(size));
  if (!ptr) {
    return MakeInt64(env, 0);
  }

  return MakeInt64(env, reinterpret_cast<int64_t>(ptr));
}

napi_value Free(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 1) {
    return ReturnUndefined(env);
  }

  int64_t ptr_value = 0;
  if (napi_get_value_int64(env, args[0], &ptr_value) != napi_ok || ptr_value == 0) {
    return ReturnUndefined(env);
  }

  std::free(reinterpret_cast<void*>(ptr_value));
  return ReturnUndefined(env);
}

napi_value AllocCopy(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 1) {
    return MakeInt64(env, 0);
  }

  void* data = nullptr;
  size_t length = 0;
  if (napi_get_arraybuffer_info(env, args[0], &data, &length) != napi_ok || data == nullptr || length == 0) {
    return MakeInt64(env, 0);
  }

  void* dest = std::malloc(length);
  if (!dest) {
    return MakeInt64(env, 0);
  }

  std::memcpy(dest, data, length);
  return MakeInt64(env, reinterpret_cast<int64_t>(dest));
}

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor descriptors[] = {
    {"alloc", nullptr, Alloc, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"free", nullptr, Free, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"allocCopy", nullptr, AllocCopy, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
  return exports;
}

}  // namespace

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
