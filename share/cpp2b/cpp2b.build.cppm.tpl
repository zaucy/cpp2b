module;

#if defined(_WIN32)
#  define CPP2B_BUILD_API extern "C" __declspec(dllexport)
#else
#  define CPP2B_BUILD_API extern "C" __attribute__((visibility("default")))
#endif

export module cpp2b.build;

import std;

struct cpp2b_detail_build_impl;
struct cpp2b_detail_git_repo_impl;
struct cpp2b_detail_cpp1_module_impl;

template<typename Signature>
using func_ptr = Signature*;

#define CPP2B_BUILD_DECL_FN(name, signature) \
  CPP2B_BUILD_API func_ptr<signature> name = nullptr

#define CPP2B_BUILD_FN_CHECK(name)                                       \
  if(name == nullptr) {                                                  \
    std::println("\033[0;31mINTERNAL ERROR\033[0m: {} is unset", #name); \
    std::exit(1);                                                        \
  }                                                                      \
  static_assert(true, "macro needs semicolon")

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_build_binary_name,
  void(
    cpp2b_detail_build_impl* impl,
    std::filesystem::path    p,
    std::string_view         name
  )
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_git_clone,
  std::shared_ptr<cpp2b_detail_git_repo_impl>(
    cpp2b_detail_build_impl* impl,
    std::string_view         clone_url,
    std::string_view         commitish
  )
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_git_repo_path,
  std::filesystem::path(const cpp2b_detail_git_repo_impl* impl)
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_create_cpp1_module,
  std::shared_ptr<cpp2b_detail_cpp1_module_impl>(cpp2b_detail_build_impl* impl)
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_cpp1_module_source_path,
  void(cpp2b_detail_cpp1_module_impl* impl, std::filesystem::path p)
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_cpp1_module_include_directory,
  void(cpp2b_detail_cpp1_module_impl* impl, std::filesystem::path p)
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_cpp1_module_system_include_directory,
  void(cpp2b_detail_cpp1_module_impl* impl, std::filesystem::path p)
);

CPP2B_BUILD_DECL_FN(
  cpp2b_detail_cpp1_module_define,
  void(
    cpp2b_detail_cpp1_module_impl* impl,
    std::string_view               name,
    std::string_view               value
  )
);

export namespace cpp2b {
class git_repo {
  std::shared_ptr<cpp2b_detail_git_repo_impl> impl;

public:
  inline git_repo(std::shared_ptr<cpp2b_detail_git_repo_impl> impl)
    : impl(impl) {
  }

  inline git_repo(const git_repo& other) : impl(other.impl) {
  }

  inline git_repo(git_repo&& other) : impl(other.impl) {
    other.impl = nullptr;
  }

  inline ~git_repo() = default;

  inline auto path() const -> std::filesystem::path {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_git_repo_path);
    return (*cpp2b_detail_git_repo_path)(impl.get());
  }
};

class cpp1_module {
  std::shared_ptr<cpp2b_detail_cpp1_module_impl> impl;

public:
  inline cpp1_module(std::shared_ptr<cpp2b_detail_cpp1_module_impl> impl)
    : impl(impl) {
  }

  inline cpp1_module(const cpp1_module& other) : impl(other.impl) {
  }

  inline cpp1_module(cpp1_module&& other) : impl(other.impl) {
    other.impl = nullptr;
  }

  inline ~cpp1_module() = default;

  inline auto source_path(std::filesystem::path p) -> cpp1_module {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_cpp1_module_source_path);
    (*cpp2b_detail_cpp1_module_source_path)(impl.get(), p);
    return *this;
  }

  inline auto include_directory(std::filesystem::path p) -> cpp1_module {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_cpp1_module_include_directory);
    (*cpp2b_detail_cpp1_module_include_directory)(impl.get(), p);
    return *this;
  }

  inline auto system_include_directory(std::filesystem::path p) -> cpp1_module {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_cpp1_module_system_include_directory);
    (*cpp2b_detail_cpp1_module_system_include_directory)(impl.get(), p);
    return *this;
  }

  inline auto define(std::string_view name, std::string_view value)
    -> cpp1_module {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_cpp1_module_define);
    (*cpp2b_detail_cpp1_module_define)(impl.get(), name, value);
    return *this;
  }
};

class build {
  cpp2b_detail_build_impl* impl;

public:
  inline build(cpp2b_detail_build_impl* impl) : impl(impl) {
  }

  inline build(const build& other) : impl(other.impl) {
  }

  inline build(build&& other) : impl(other.impl) {
    other.impl = nullptr;
  }

  inline ~build() = default;

  /**
   * Renames a binary. By default binary names are the same name as their
   * source file path with the extension replaced with the target platforms
   * executable extension.
   */
  inline auto binary_name(
    std::filesystem::path binary_source_path,
    std::string_view      new_binary_name
  ) -> void {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_build_binary_name);
    return (*cpp2b_detail_build_binary_name)(
      impl,
      binary_source_path,
      new_binary_name
    );
  }

  inline auto git_clone(std::string_view clone_url, std::string_view commitish)
    -> git_repo {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_git_clone);
    return git_repo{(*cpp2b_detail_git_clone)(impl, clone_url, commitish)};
  }

  inline auto cpp1_module() -> cpp1_module {
    CPP2B_BUILD_FN_CHECK(cpp2b_detail_create_cpp1_module);
    return ::cpp2b::cpp1_module{(*cpp2b_detail_create_cpp1_module)(impl)};
  }
};

} // namespace cpp2b

extern "C" void build(cpp2b::build& b);

CPP2B_BUILD_API void cpp2b_detail_build(cpp2b_detail_build_impl* impl) {
  cpp2b::build b(impl);
  ::build(b);
}
