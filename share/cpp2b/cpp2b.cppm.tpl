module;

#ifdef _MSC_VER
#	include <Windows.h>
#else
#	include <stdlib.h>
#endif

export module cpp2b;

import std;
import std.compat;

#ifdef _MSC_VER
	extern char **_environ;
#else
	extern "C" char **environ;
#endif

export namespace cpp2b {

enum class platform { linux, macos, windows };
enum class compiler_type { gcc, clang, msvc };
enum class compilation_type { debug, optimized, fast };

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
} // namespace cpp2b

export namespace cpp2b::env {
inline auto set_var(const std::string& name, const std::string& value) -> void {
#if defined(_MSC_VER)
	SetEnvironmentVariableA(name.c_str(), value.c_str());
#else
	setenv(name.c_str(), value.c_str(), 1);
#endif
}

inline auto set_var(auto name, auto value) -> void {
	return cpp2b::env::set_var(std::string{name}, std::string{value});
}

inline auto get_var(const std::string& name) -> std::optional<std::string> {
#if defined(_MSC_VER)
	auto val = std::string{""};
	val.resize(GetEnvironmentVariableA(name.c_str(), val.data(), 1));

	if(!val.empty()) {
		GetEnvironmentVariableA(name.c_str(), val.data(), val.size() + 1);
		return val;
	}
#else
	auto val = std::getenv(name.c_str());
	if(val != nullptr) {
		return std::string{val};
	}
#endif

	return {};
}

inline auto get_var(auto name) -> std::optional<std::string> {
	return cpp2b::env::get_var(std::string{name});
}

class vars {
public:
	struct entry {
		std::string_view name;
		std::string_view value;
	};

	class iterator {
	public:
		using iterator_category = std::forward_iterator_tag;
		using value_type = entry;
		using difference_type = std::ptrdiff_t;
		using pointer = const value_type*;
		using reference = const value_type&;

		iterator(char** env) : env_(env) {
			if (env_ && *env_) {
				update_entry();
			}
		}

		reference operator*() const noexcept {
			return current_entry_;
		}

		pointer operator->() const noexcept {
			return &current_entry_;
		}

		iterator& operator++() noexcept {
			if (env_ && *env_) {
				++env_;
				if (*env_) {
					update_entry();
				} else {
					env_ = nullptr; // end of iteration
				}
			}
			return *this;
		}

		iterator operator++(int) noexcept {
			iterator temp = *this;
			++(*this);
			return temp;
		}

		friend bool operator==(const iterator& a, const iterator& b) noexcept {
			return a.env_ == b.env_;
		}

		friend bool operator!=(const iterator& a, const iterator& b) noexcept {
			return !(a == b);
		}

	private:
		void update_entry() noexcept {
			if (env_ && *env_) {
				std::string_view env_str(*env_);
				auto pos = env_str.find('=');
				if (pos != std::string_view::npos) {
					current_entry_.name = env_str.substr(0, pos);
					current_entry_.value = env_str.substr(pos + 1);
				}
			}
		}

		char** env_ = nullptr;
		value_type current_entry_;
	};

	iterator begin() const noexcept {
#ifdef _MSC_VER
		return iterator(_environ);
#else
		return iterator(environ);
#endif
	}

	iterator end() const noexcept {
		return iterator(nullptr);
	}
};

std::filesystem::path executable_path() {
	static std::string executable_path_str;

	if(!executable_path_str.empty()) {
		return executable_path_str;
	}

	if constexpr(host_platform() == platform::windows) {
		auto size = MAX_PATH;
		auto buffer = std::vector<char>(size);

		for (;;) {
			DWORD len = GetModuleFileNameA(NULL, buffer.data(), size);
			if (len == 0) {
				executable_path_str = {};
				return executable_path_str;
			} else if (len < size - 1) {
				executable_path_str = std::string(buffer.data(), len);
				return executable_path_str;
			}

			size *= 2;
			buffer.resize(size);
		}
	}
}
}
