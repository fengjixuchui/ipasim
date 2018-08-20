// Compiled with:
// ..\..\build\bin\clang -target i386-pc-windows-msvc -c dyld_initializer.cpp -DDLL -o ..\..\Debug\dyld_dll_initializer.obj -g -gcodeview
// ..\..\build\bin\clang -target i386-pc-windows-msvc -c dyld_initializer.cpp -DEXE -o ..\..\Debug\dyld_exe_initializer.obj -g -gcodeview

#include <Windows.h>

extern "C" char _mh_dylib_header;
extern "C" void _dyld_initialize(void*);
extern "C" void _objc_init(void);
extern "C" BOOL WINAPI _DllMainCRTStartup(
    HINSTANCE const instance,
    DWORD     const reason,
    LPVOID    const reserved
);
extern "C" int mainCRTStartup();

static bool initialized = false;
extern "C" BOOL WINAPI dyld_entrypoint(HINSTANCE const instance, DWORD const reason, LPVOID const reserved) {
    // Don't initialize twice.
    if (reason == DLL_PROCESS_ATTACH && initialized) {
        return true;
    }

    initialized = true;

    // Register itself within `dyld` if not already registered.
    _dyld_initialize(&_mh_dylib_header);
    // Initialize the Objective-C runtime if not already initialized.
    _objc_init();
    // Initialize the C++ runtime.
#if defined(DLL)
    return _DllMainCRTStartup(instance, reason, reserved);
#elif defined(EXE)
    return mainCRTStartup();
#else
#error Either `DLL` or `EXE` has to be defined.
#endif
}
extern "C" __declspec(dllexport) void dyld_initializer(HINSTANCE const instance) {
    if (!initialized) {
        // TODO: `reserved` shouldn't probably be null since the DLL is actually statically loaded.
        dyld_entrypoint(instance, DLL_PROCESS_ATTACH, /* reserved: */ nullptr);
    }
}
