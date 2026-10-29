// Parses Delphi files with tree-sitter, walks every node, and lists where the
// grammar groups a `<` wrongly: as the right operand of a tighter operator,
// A + (B < C), or of `not`, where Delphi reads (A + B) < C.
//
//   tswalk <file or folder>...   (a folder: its .pas files, recursively)
//
// The same program as delphi\TsWalk.dpr, in C++17 for C++Builder's bcc64x.

#include <tree_sitter/api.h>

#include <windows.h>

#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>

extern "C" const TSLanguage *tree_sitter_delphi13(void);

namespace fs = std::filesystem;

static long long nodes = 0, found = 0;
static std::string current;   // the file being walked, written before its first finding

// A file as UTF-8, read the way Delphi's TFile.ReadAllText reads it: by its
// byte order mark, or else in the ANSI code page.
static std::string read_utf8(const fs::path &path)
{
    std::ifstream in(path, std::ios::binary);
    std::string bytes((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());

    if (bytes.compare(0, 3, "\xEF\xBB\xBF") == 0)
        return bytes.substr(3);

    std::wstring wide;
    if (bytes.compare(0, 2, "\xFF\xFE") == 0)
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

static TSNode field(TSNode node, const char *name)
{
    return ts_node_child_by_field_name(node, name, (uint32_t)std::strlen(name));
}

static std::string kind(TSNode node)
{
    return ts_node_is_null(node) ? "" : ts_node_type(node);
}

// a node's text, on one line: a line break and the indent after it become a space
static std::string text(const std::string &source, TSNode node)
{
    if (ts_node_is_null(node))
        return "";
    uint32_t start = ts_node_start_byte(node);
    std::string result;
    for (uint32_t i = start, end = ts_node_end_byte(node); i < end; ++i)
        if (source[i] == '\r' || source[i] == '\n')
        {
            while (i + 1 < end && std::isspace((unsigned char)source[i + 1]))
                ++i;
            result += ' ';
        }
        else
            result += source[i];
    return result;
}

// the adding and multiplying operators, which bind tighter than a comparison
static bool tighter(const std::string &op)
{
    for (const char *t : {"kAdd", "kSub", "kOr", "kXor", "kMul", "kFdiv", "kDiv", "kMod", "kAnd", "kShl", "kShr"})
        if (op == t)
            return true;
    return false;
}

static void check(const std::string &source, TSNode node)
{
    bool unary = kind(node) == "exprUnary";
    std::string op = kind(field(node, "operator"));
    if (!(tighter(op) || (unary && op == "kNot")))
        return;

    TSNode inner = field(node, unary ? "operand" : "rhs");
    if (kind(inner) != "exprBinary" || kind(field(inner, "operator")) != "kLt")
        return;

    ++found;
    if (!current.empty())
    {
        std::printf("%s\n", current.c_str());
        current.clear();
    }
    std::string head = unary ? "not" : text(source, field(node, "lhs")) + " " + text(source, field(node, "operator"));
    std::string b = text(source, field(inner, "lhs"));
    std::string c = text(source, field(inner, "rhs"));
    std::printf("%6u  tree-sitter: %s (%s < %s)   Delphi: (%s %s) < %s\n",
                ts_node_start_point(node).row + 1, head.c_str(), b.c_str(), c.c_str(),
                head.c_str(), b.c_str(), c.c_str());
}

static void walk(const std::string &source, TSNode node)
{
    ++nodes;
    std::string k = ts_node_type(node);
    if (k == "exprBinary" || k == "exprUnary")
        check(source, node);
    for (uint32_t i = 0, n = ts_node_child_count(node); i < n; ++i)
        walk(source, ts_node_child(node, i));
}

static void walk_file(TSParser *parser, const fs::path &path)
{
    current = path.string();
    std::string source = read_utf8(path);
    TSTree *tree = ts_parser_parse_string(parser, nullptr, source.data(), (uint32_t)source.size());
    walk(source, ts_tree_root_node(tree));
    ts_tree_delete(tree);
}

int main(int argc, char **argv)
{
    TSParser *parser = ts_parser_new();
    if (!ts_parser_set_language(parser, tree_sitter_delphi13()))
    {
        std::fprintf(stderr, "tree-sitter: this runtime doesn't take the language's ABI version\n");
        return 1;
    }

    int files = 0;
    auto start = std::chrono::steady_clock::now();
    for (int i = 1; i < argc; ++i)
    {
        fs::path arg = argv[i];
        if (fs::is_directory(arg))
        {
            for (const auto &entry : fs::recursive_directory_iterator(arg))
                if (entry.is_regular_file() && entry.path().extension() == ".pas")
                {
                    walk_file(parser, entry.path());
                    ++files;
                }
        }
        else
        {
            walk_file(parser, arg);
            ++files;
        }
    }
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count();
    std::printf("%d files, %lld nodes, %lld misgrouped <, %lld ms\n", files, nodes, found, (long long)ms);

    ts_parser_delete(parser);
    return 0;
}
