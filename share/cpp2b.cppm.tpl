export module cpp2b;

import std;

export namespace cpp2b {

enum class platform { linux, macos, windows };
enum class compiler_type { gcc, clang, msvc };
enum class compilation_type { debug, optimized, fast };
enum class build_type { local, development, release };

constexpr auto host_platform() -> platform {
#if defined(_WIN32)
	return platform::windows;
#elif defined(__APPLE__)
	return platform::macos;
#elif defined(__linux__)
	return platform::linux;
#else
#	error unknown platform
#endif
}

constexpr auto target_platform() -> platform {
	return host_platform();
}

constexpr auto compiler() -> compiler_type {
#if defined(_MSC_VER)
	return compiler_type::msvc;
#elif defined(__clang__)
	return compiler_type::clang;
#elif defined(__GNUC__)
	return compiler_type::gcc;
#else
#	error unknown compiler
#endif
}

constexpr auto build() -> build_type {
	return build_type::local;
}

constexpr auto install_dir() -> const std::string_view {
	if constexpr (build() == build_type::local) {
		return R"_____cpp2b_____(@CPP2B_PROJECT_ROOT@)_____cpp2b_____";
	}
}

} // namespace cpp2b
