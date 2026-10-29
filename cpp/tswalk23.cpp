// Parses Delphi files with tree-sitter, walks every node, and lists where the
// grammar groups a `<` wrongly: as the right operand of a tighter operator,
// A + (B < C), or of `not`, where Delphi reads (A + B) < C.
//
//   tswalk23 <file or folder>...   (a folder: its .pas files, recursively)
//
// The same program as tswalk.cpp, written in C++23 for C++Builder's bcc64x:
// std::print, std::expected, ranges, and the C handles owned by unique_ptr.

#include <tree_sitter/api.h>

#include <windows.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <expected>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <memory>
#include <print>
#include <ranges>
#include <regex>
#include <span>
#include <string>
#include <string_view>

extern "C" const TSLanguage *tree_sitter_delphi13(void);

namespace fs = std::filesystem;

using Parser = std::unique_ptr<TSParser, decltype(&ts_parser_delete)>;
using Tree   = std::unique_ptr<TSTree, decltype(&ts_tree_delete)>;

struct Totals
{
    long long nodes = 0;
    long long found = 0;
};

// A file as UTF-8, read the way Delphi's TFile.ReadAllText reads it: by its
// byte order mark, or else in the ANSI code page.
static std::expected<std::string, std::string> read_utf8(const fs::path &path)
{
    std::ifstream in(path, std::ios::binary);
    if (!in)
        return std::unexpected("can't open " + path.string());
    std::string bytes{std::istreambuf_iterator<char>(in), {}};

    if (bytes.starts_with("\xEF\xBB\xBF"))
        return bytes.substr(3);

    std::wstring wide;
    if (bytes.starts_with("\xFF\xFE"))
        wide.assign(reinterpret_cast<const wchar_t *>(bytes.data() + 2), (bytes.size() - 2) / 2);
    else
    {
        wide.resize(MultiByteToWideChar(CP_ACP, 0, bytes.data(), (int)bytes.size(), nullptr, 0));
        MultiByteToWideChar(CP_ACP, 0, bytes.data(), (int)bytes.size(), wide.data(), (int)wide.size());
    }
    std::string utf8(WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(), nullptr, 0, nullptr, nullptr), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide.data(), (int)wide.size(), utf8.data(), (int)utf8.size(), nullptr, nullptr);
    return utf8;
}

class Walker
{
public:
    Walker(std::string_view source, std::string name, Totals &totals)
        : source_(source), name_(std::move(name)), totals_(totals) {}

    void walk(TSNode node)
    {
        ++totals_.nodes;
        if (std::string_view k = ts_node_type(node); k == "exprBinary" || k == "exprUnary")
            check(node);
        for (uint32_t i : std::views::iota(0u, ts_node_child_count(node)))
            walk(ts_node_child(node, i));
    }

private:
    std::string_view source_;
    std::string      name_;    // written before the file's first finding, then cleared
    Totals          &totals_;

    static TSNode field(TSNode node, std::string_view name)
    {
        return ts_node_child_by_field_name(node, name.data(), (uint32_t)name.size());
    }

    static std::string_view kind(TSNode node)
    {
        return ts_node_is_null(node) ? "" : ts_node_type(node);
    }

    // a node's text, on one line: a line break and the indent after it become a space
    std::string text(TSNode node) const
    {
        if (ts_node_is_null(node))
            return {};
        auto start = ts_node_start_byte(node);
        std::string raw{source_.substr(start, ts_node_end_byte(node) - start)};
        static const std::regex line_break{R"([\r\n]\s*)"};
        return std::regex_replace(raw, line_break, " ");
    }

    // the adding and multiplying operators, which bind tighter than a comparison
    static bool tighter(std::string_view op)
    {
        static constexpr std::array<std::string_view, 11> ops{
            "kAdd", "kSub", "kOr", "kXor", "kMul", "kFdiv", "kDiv", "kMod", "kAnd", "kShl", "kShr"};
        return std::ranges::contains(ops, op);
    }

    void check(TSNode node)
    {
        bool unary = kind(node) == "exprUnary";
        auto op    = kind(field(node, "operator"));
        if (!(tighter(op) || (unary && op == "kNot")))
            return;

        TSNode inner = field(node, unary ? "operand" : "rhs");
        if (kind(inner) != "exprBinary" || kind(field(inner, "operator")) != "kLt")
            return;

        ++totals_.found;
        if (!name_.empty())
            std::println("{}", std::exchange(name_, {}));
        auto head = unary ? std::string{"not"} : text(field(node, "lhs")) + " " + text(field(node, "operator"));
        auto b    = text(field(inner, "lhs"));
        auto c    = text(field(inner, "rhs"));
        std::println("{:6}  tree-sitter: {} ({} < {})   Delphi: ({} {}) < {}",
                     ts_node_start_point(node).row + 1, head, b, c, head, b, c);
    }
};

static void walk_file(TSParser *parser, const fs::path &path, Totals &totals)
{
    auto source = read_utf8(path);
    if (!source)
    {
        std::println(stderr, "{}", source.error());
        return;
    }
    Tree tree{ts_parser_parse_string(parser, nullptr, source->data(), (uint32_t)source->size()), ts_tree_delete};
    Walker{*source, path.string(), totals}.walk(ts_tree_root_node(tree.get()));
}

int main(int argc, char **argv)
{
    Parser parser{ts_parser_new(), ts_parser_delete};
    if (!ts_parser_set_language(parser.get(), tree_sitter_delphi13()))
    {
        std::println(stderr, "tree-sitter: this runtime doesn't take the language's ABI version");
        return 1;
    }

    auto is_pas = [](const fs::directory_entry &e) { return e.is_regular_file() && e.path().extension() == ".pas"; };

    Totals totals;
    int files = 0;
    auto start = std::chrono::steady_clock::now();
    for (fs::path arg : std::span(argv + 1, argc - 1))
    {
        if (fs::is_directory(arg))
            for (const auto &entry : fs::recursive_directory_iterator(arg) | std::views::filter(is_pas))
            {
                walk_file(parser.get(), entry.path(), totals);
                ++files;
            }
        else
        {
            walk_file(parser.get(), arg, totals);
            ++files;
        }
    }
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start);
    std::println("{} files, {} nodes, {} misgrouped <, {} ms", files, totals.nodes, totals.found, ms.count());
}
