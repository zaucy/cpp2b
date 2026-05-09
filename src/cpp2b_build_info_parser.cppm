module;
#include "parse.h"
export module cpp2b_build_info_parser;

import std;

export namespace cpp2b_build_info_parser {

enum class source_kind { unknown, module, binary, build };

struct source_info {
  source_kind                        kind = source_kind::unknown;
  std::string                        module_name;
  std::vector<std::string>           imports;
  std::map<std::string, std::string> constants;
  bool                               exported = false;
};

source_info parse_source(const std::string& filename) {
  auto result = source_info{};
  auto errors = std::vector<cpp2::error_entry>{};
  auto source = cpp2::source{errors};

  if(!source.load(filename)) {
    return result;
  }

  // Extract imports from source lines
  for(auto const& line : source.get_lines()) {
    if(line.cat == cpp2::source_line::category::import) {
      std::string text = line.text;
      // Basic extraction: import <name> ;
      size_t import_pos = text.find("import");
      if(import_pos != std::string::npos) {
        std::string import_name;
        size_t      k = import_pos + 6;
        while(k < text.size() && std::isspace(text[k])) {
          k++;
        }
        while(k < text.size() && !std::isspace(text[k]) && text[k] != ';') {
          import_name += text[k];
          k++;
        }
        if(!import_name.empty()) {
          result.imports.emplace_back(import_name);
        }
      }
    }
  }

  cpp2::tokens tokens(errors);
  tokens.lex(source.get_lines());

  std::vector<cpp2::token> all_tokens;
  for(auto const& [line, line_tokens] : tokens.get_map()) {
    for(auto const& t : line_tokens) {
      all_tokens.push_back(t);
    }
  }

  std::filesystem::path p(filename);
  if(p.filename() == "build.cpp2") {
    result.kind = source_kind::build;
    // Extract constants
    for(size_t j = 0; j < all_tokens.size(); ++j) {
      auto name = all_tokens[j].as_string_view();

      // Specific handling for 'compiler :== ...'
      if(name == "compiler" && j + 2 < all_tokens.size() &&
         all_tokens[j + 1].type() == cpp2::lexeme::Colon &&
         all_tokens[j + 2].type() == cpp2::lexeme::EqualComparison) {
        size_t k = j + 3;
        auto   match_path = [&](const std::vector<std::string_view>& parts) {
          size_t cur = k;
          for(size_t i = 0; i < parts.size(); ++i) {
            if(cur >= all_tokens.size()) {
              return false;
            }
            if(all_tokens[cur].as_string_view() != parts[i]) {
              return false;
            }
            cur++;
            if(i < parts.size() - 1) {
              if(cur >= all_tokens.size()) {
                return false;
              }
              if(all_tokens[cur].as_string_view() == "::") {
                cur++;
              } else if(cur + 1 < all_tokens.size() &&
                        all_tokens[cur].as_string_view() == ":" &&
                        all_tokens[cur + 1].as_string_view() == ":") {
                cur += 2;
              } else {
                return false;
              }
            }
          }
          k = cur;
          return true;
        };

        // Case 1: compiler :== cpp2b::compiler_choice::<value>;
        if(match_path({"cpp2b", "compiler_choice"})) {
          bool has_scope = false;
          if(k < all_tokens.size() && all_tokens[k].as_string_view() == "::") {
            k++;
            has_scope = true;
          } else if(k + 1 < all_tokens.size() &&
                    all_tokens[k].as_string_view() == ":" &&
                    all_tokens[k + 1].as_string_view() == ":") {
            k += 2;
            has_scope = true;
          }

          if(has_scope && k < all_tokens.size() &&
             all_tokens[k].type() == cpp2::lexeme::Identifier) {
            result.constants["compiler"] =
              std::string(all_tokens[k].as_string_view());
            j = k;
            continue;
          }
        }
      }

      // identifier == string_literal ;
      if(j + 3 < all_tokens.size() &&
         all_tokens[j].type() == cpp2::lexeme::Identifier &&
         all_tokens[j + 1].type() == cpp2::lexeme::EqualComparison &&
         all_tokens[j + 2].type() == cpp2::lexeme::StringLiteral &&
         all_tokens[j + 3].type() == cpp2::lexeme::Semicolon) {
        auto name = all_tokens[j].as_string_view();
        auto value_raw = all_tokens[j + 2].as_string_view();
        if(value_raw.size() >= 2) {
          auto value = std::string(value_raw.substr(1, value_raw.size() - 2));
          result.constants[std::string(name)] = value;
        }
        j += 3;
      }
      // identifier :== string_literal ;
      else if(j + 3 < all_tokens.size() &&
              all_tokens[j].type() == cpp2::lexeme::Identifier &&
              all_tokens[j + 1].type() == cpp2::lexeme::Colon &&
              all_tokens[j + 2].type() == cpp2::lexeme::EqualComparison &&
              all_tokens[j + 3].type() == cpp2::lexeme::StringLiteral) {
        auto name = all_tokens[j].as_string_view();
        auto value_raw = all_tokens[j + 3].as_string_view();
        if(value_raw.size() >= 2) {
          auto value = std::string(value_raw.substr(1, value_raw.size() - 2));
          result.constants[std::string(name)] = value;
        }
        j += 3;
      }
      // identifier : type == string_literal ;
      else if(j + 5 < all_tokens.size() &&
              all_tokens[j].type() == cpp2::lexeme::Identifier &&
              all_tokens[j + 1].type() == cpp2::lexeme::Colon &&
              all_tokens[j + 3].type() == cpp2::lexeme::EqualComparison &&
              all_tokens[j + 4].type() == cpp2::lexeme::StringLiteral &&
              all_tokens[j + 5].type() == cpp2::lexeme::Semicolon) {
        auto name = all_tokens[j].as_string_view();
        auto value_raw = all_tokens[j + 4].as_string_view();
        if(value_raw.size() >= 2) {
          auto value = std::string(value_raw.substr(1, value_raw.size() - 2));
          result.constants[std::string(name)] = value;
        }
        j += 5;
      }
    }
  } else {
    // Module detection
    for(size_t k = 0; k + 2 < all_tokens.size(); ++k) {
      if(all_tokens[k].as_string_view() == "export" &&
         all_tokens[k + 1].as_string_view() == "module" &&
         all_tokens[k + 2].type() == cpp2::lexeme::Identifier) {
        result.kind = source_kind::module;
        result.module_name = std::string(all_tokens[k + 2].as_string_view());
        result.exported = true;
        return result;
      }
    }

    // Binary detection
    for(auto const& t : all_tokens) {
      if(t.type() == cpp2::lexeme::Identifier && t.as_string_view() == "main") {
        result.kind = source_kind::binary;
        return result;
      }
    }
  }

  return result;
}

} // namespace cpp2b_build_info_parser
