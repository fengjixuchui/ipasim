# TAPI

Forked from <https://github.com/ributzka/tapi>.

## Building

```cmd
mkdir build && cd build
mkdir Debug && cd Debug
cmake -G Ninja -C "..\..\cmake\caches\apple-tapi.cmake" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=..\..\..\..\build -DLLVM_ENABLE_PROJECTS="tapi" ..\..\..\llvm
```
