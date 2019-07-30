# CMake

Here we describe our journey towards building with CMake in Docker.

## How to compile Clang and then use it as a compiler

This is inherently problematic in CMake because it expects only one C++ compiler
in the whole project. See [[CMake] One build, multiple compilers and
packages](https://cmake.org/pipermail/cmake/2013-August/055574.html). There is
one Stack Overflow question ([Compile a compiler as an external project and use
it?](https://stackoverflow.com/q/39178338)) of a person with similar problem.
The answer there actually lists possible solutions pretty well. We decided to
manually invoke CMake for Clang and then for our project itself at configure
time. This is also known as a *superbuild* configuration. Then, we add
`clang.exe` as a custom target that runs Ninja for Clang before building our
project.

Other related sites:

- SO: [Using CMake with multiple compilers for the same
  language](https://stackoverflow.com/q/9542971).
- SO: [Building a tool immediately so it can be used later in same CMake
  run](https://stackoverflow.com/q/36084785).
- Kitware Blog: [CMake Superbuilds and Git
  Submodules](https://blog.kitware.com/cmake-superbuilds-git-submodules/).
- SO: [How to use CMake ExternalProject_Add or alternatives in a cross platform
  way?](https://stackoverflow.com/a/30011890).
- SO: [Run a CMake superbuild once and only
  once](https://stackoverflow.com/q/48339178).

## How to compile with `clang`, not `clang-cl`

This is a known issue: [Add support for Clang targeting MSVC ABI but with
GNU-like command line](https://gitlab.kitware.com/cmake/cmake/issues/16439). See
also [Building with CMake, Ninja and Clang on
Windows](https://stackoverflow.com/a/46593308). Or maybe
[cmake-toolchains(7)](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
could be useful. Anyway, in general, here are the ways to specify custom
compiler in CMake: [How do I use a different
compiler?](https://gitlab.kitware.com/cmake/community/wikis/FAQ#how-do-i-use-a-different-compiler).
Also see [this SO answer](https://stackoverflow.com/a/13089688) which references
that article.

## How to use `lld-link` instead of `clang` to link `.obj` files

- SO: [CMake custom Link executable command, how to extract linker
  options?](https://stackoverflow.com/q/37368434).
- SO: [CMake: use a custom linker](https://stackoverflow.com/a/25274328).

## Tips and tricks

### Dependencies

`DEPENDS` of `add_custom_target` just builds files listed if there is any
`add_custom_command` that can build them. To add target dependencies, you have
to use `add_dependencies`.

`DEPENDS` of `add_custom_command`, on the other hand, is far more advanced. It
can specify outputs of other custom commands, other targets and also arbitrary
files. If you specify an arbitrary file (i.e., file that is not an output of a
custom command), the custom command is re-run every time the file is changed.
