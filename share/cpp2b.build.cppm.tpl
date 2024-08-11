module;

#if defined(_WIN32)
#  define CPP2B_BUILD_API extern "C" __declspec(dllexport)
#else
#  define CPP2B_BUILD_API extern "C" __attribute__((visibility("default")))
#endif

export module cpp2b.build;

import std;

struct cpp2b_detail_build_impl;
CPP2B_BUILD_API void (*cpp2b_detail_build_binary_name)(
    cpp2b_detail_build_impl *, std::filesystem::path,
    std::string_view) = nullptr;

export namespace cpp2b {
class build {
  cpp2b_detail_build_impl *impl;

public:
  inline build(cpp2b_detail_build_impl *impl) : impl(impl) {}
  inline build(const build &other) : impl(other.impl) {}
  inline build(build &&other) : impl(other.impl) { other.impl = nullptr; }
  inline ~build() = default;
  /**
   * Renames a binary. By default binary names are the same name as their source
   * file path with the extension replaced with the target platforms executable
   * extension.
   */
  inline auto binary_name(std::filesystem::path binary_source_path,
                          std::string_view new_binary_name) -> void {
    return (*cpp2b_detail_build_binary_name)(impl, binary_source_path,
                                             new_binary_name);
  }
};
} // namespace cpp2b

extern "C" void build(cpp2b::build &b);

CPP2B_BUILD_API void cpp2b_detail_build(cpp2b_detail_build_impl *impl) {
  cpp2b::build b(impl);
  ::build(b);
}
