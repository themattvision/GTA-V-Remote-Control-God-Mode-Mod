#pragma once

#include <cstdint>
#include <type_traits>
#include <windows.h>

using Hash = std::uint64_t;
using Any = std::uint64_t;
using Entity = int;
using Ped = int;
using Player = int;
using Vehicle = int;

void scriptWait(DWORD milliseconds);
void scriptRegister(HMODULE module, void (*scriptMain)());
void scriptUnregister(HMODULE module);
void nativeInit(Hash hash);
void nativePush64(Any value);
std::uint64_t* nativeCall();

namespace ScriptHook {
    template <typename Value>
    std::uint64_t argument(Value value) {
        if constexpr (std::is_pointer_v<Value>) {
            return reinterpret_cast<std::uintptr_t>(value);
        } else {
            return static_cast<std::uint64_t>(value);
        }
    }

    template <typename Result>
    Result invoke(Hash hash) {
        nativeInit(hash);
        return static_cast<Result>(*nativeCall());
    }

    template <typename Result, typename First, typename... Rest>
    Result invoke(Hash hash, First first, Rest... rest) {
        nativeInit(hash);
        nativePush64(argument(first));
        (nativePush64(argument(rest)), ...);
        return static_cast<Result>(*nativeCall());
    }

    inline void invokeVoid(Hash hash) {
        nativeInit(hash);
        nativeCall();
    }

    template <typename First, typename... Rest>
    void invokeVoid(Hash hash, First first, Rest... rest) {
        nativeInit(hash);
        nativePush64(argument(first));
        (nativePush64(argument(rest)), ...);
        nativeCall();
    }
}
