/* tree-sitter's runtime as bcc32c compiles it for Win32 (build-c.cmd win32).

   tree-sitter's stack.c defines `forceinline` as MSVC's __forceinline on
   Windows without __GNUC__, and as `static inline` elsewhere. bcc64x defines
   __GNUC__; bcc32c doesn't, so it took __forceinline, which in C leaves no
   body for a function whose address is taken (pop_count_callback and four
   others), and dcc32 couldn't link them. This gives bcc32c what bcc64x gets. */
#define __forceinline static inline
#include "tree-sitter/src/lib.c"
