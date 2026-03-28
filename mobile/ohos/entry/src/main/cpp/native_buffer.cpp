#include <cstdint>
#include <cstdlib>
#include <cstring>

#include <napi/native_api.h>
#include <js_native_api.h>

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

napi_value Allocate(napi_env env, napi_callback_info info) {
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

napi_value Realloc(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 2) {
    return MakeInt64(env, 0);
  }

  int64_t ptr_value = 0;
  int64_t size = 0;
  if (napi_get_value_int64(env, args[0], &ptr_value) != napi_ok ||
      napi_get_value_int64(env, args[1], &size) != napi_ok ||
      ptr_value == 0 || size <= 0) {
    return MakeInt64(env, 0);
  }

  void* ptr = std::realloc(reinterpret_cast<void*>(ptr_value), static_cast<size_t>(size));
  if (!ptr) {
    return MakeInt64(env, 0);
  }

  return MakeInt64(env, reinterpret_cast<int64_t>(ptr));
}

napi_value Copy(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4];
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  if (argc < 4) {
    return MakeInt64(env, 0);
  }

  void* data = nullptr;
  size_t source_length = 0;
  if (napi_get_arraybuffer_info(env, args[0], &data, &source_length) != napi_ok ||
      data == nullptr || source_length == 0) {
    return MakeInt64(env, 0);
  }

  int64_t dest_value = 0;
  int64_t offset_value = 0;
  int64_t length_value = 0;
  if (napi_get_value_int64(env, args[1], &dest_value) != napi_ok ||
      napi_get_value_int64(env, args[2], &offset_value) != napi_ok ||
      napi_get_value_int64(env, args[3], &length_value) != napi_ok ||
      dest_value == 0 || offset_value < 0) {
    return MakeInt64(env, 0);
  }

  size_t copy_length = source_length;
  if (length_value > 0 && static_cast<size_t>(length_value) < copy_length) {
    copy_length = static_cast<size_t>(length_value);
  }
  if (copy_length == 0) {
    return MakeInt64(env, 0);
  }

  void* dest = reinterpret_cast<void*>(dest_value + offset_value);
  std::memcpy(dest, data, copy_length);
  return MakeInt64(env, static_cast<int64_t>(copy_length));
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor descriptors[] = {
    {"allocate", nullptr, Allocate, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"free", nullptr, Free, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"realloc", nullptr, Realloc, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"copy", nullptr, Copy, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
  return exports;
}

}  // namespace

EXTERN_C_START
static napi_module native_buffer_module = {
    1,
    0,
    nullptr,
    Init,
    "native_buffer",
    nullptr,
    {0},
};

static void RegisterNativeBufferModule(void) __attribute__((constructor));
static void RegisterNativeBufferModule(void) {
  napi_module_register(&native_buffer_module);
}
EXTERN_C_END
