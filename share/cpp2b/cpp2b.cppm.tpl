module;

#ifdef _MSC_VER
#  include <Windows.h>
#else
#  include <stdlib.h>
#  include <unistd.h>
#endif

export module cpp2b;

import std;
import std.compat;

#ifdef _MSC_VER
extern char** _environ;
#else
extern "C" char** environ;
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
#  error unknown platform
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
#  error unknown compiler
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
  DWORD val_len = GetEnvironmentVariableA(name.c_str(), nullptr, 0);
  if(val_len == 0) {
    return {};
  }

  auto val = std::string(val_len - 1, '\0');
  GetEnvironmentVariableA(name.c_str(), val.data(), val_len);
  return val;
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
      if(env_ && *env_) {
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
      if(env_ && *env_) {
        ++env_;
        if(*env_) {
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
      if(env_ && *env_) {
        std::string_view env_str(*env_);
        auto             pos = env_str.find('=');
        if(pos != std::string_view::npos) {
          current_entry_.name = env_str.substr(0, pos);
          current_entry_.value = env_str.substr(pos + 1);
        }
      }
    }

    char**     env_ = nullptr;
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

  auto size = 260;
  auto buffer = std::vector<char>(size);

#if defined(_WIN32)
  for(;;) {
    DWORD len = GetModuleFileNameA(NULL, buffer.data(), size);
    if(len == 0) {
      executable_path_str = {};
      return executable_path_str;
    } else if(len < size - 1) {
      executable_path_str = std::string(buffer.data(), len);
      return executable_path_str;
    }

    size += 260;
    buffer.resize(size);
  }
#elif defined(__linux__)
  for(;;) {
    ssize_t len = readlink("/proc/self/exe", buffer.data(), size - 1);
    if(len < 0) {
      executable_path_str = {};
      return executable_path_str;
    } else if(len < size - 1) {
      executable_path_str = std::string(buffer.data(), len);
      return executable_path_str;
    }

    size += 260;
    buffer.resize(size);
  }
#else
#  error unhandled executable_path platform
#endif
}
} // namespace cpp2b::env

export namespace cpp2b::os {
auto get_last_error() -> std::string {
#if defined(_WIN32)
  DWORD errorMessageID = ::GetLastError();
  if(errorMessageID == 0) {
    return {}; // No error
  }

  LPSTR messageBuffer = nullptr;

  size_t size = FormatMessageA(
    FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS,
    nullptr,
    errorMessageID,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPSTR)&messageBuffer,
    0,
    nullptr
  );

  auto message = std::string{messageBuffer, size - 1};

  LocalFree(messageBuffer);

  return message;
#else
  int errnum = errno;

#  if (_POSIX_C_SOURCE >= 200112L) && !_GNU_SOURCE
  // Use thread-safe strerror_r (POSIX version)
  char buffer[256];
  if(strerror_r(errnum, buffer, sizeof(buffer)) == 0) {
    return std::string(buffer);
  } else {
    return "Unknown error";
  }
#  else
  // Use GNU-specific strerror_r, which returns a char*
  char buffer[256];
  return std::string(strerror_r(errnum, buffer, sizeof(buffer)));
#  endif

#endif
}
} // namespace cpp2b::os
