param(
    [Parameter(Mandatory=$true)][string]$LuaLibrary
)
# Use a PowerShell process matching the installed Lua 5.1 library architecture.
# No dependencies are installed. On macOS: lua5.1 tools/verify.lua
$ErrorActionPreference = 'Stop'
$library = (Resolve-Path -LiteralPath $LuaLibrary).Path.Replace('\', '\\').Replace('"', '\"')
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DuoLua {
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr luaL_newstate();
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern void luaL_openlibs(IntPtr state);
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern int luaL_loadfile(IntPtr state, string file);
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern int lua_pcall(IntPtr state, int args, int results, int error);
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr lua_tolstring(IntPtr state, int index, IntPtr length);
    [DllImport("$library", CallingConvention=CallingConvention.Cdecl)] public static extern void lua_close(IntPtr state);
}
"@
$state = [DuoLua]::luaL_newstate()
if ($state -eq [IntPtr]::Zero) { throw 'Lua allocation failed' }
try {
    [DuoLua]::luaL_openlibs($state)
    $result = [DuoLua]::luaL_loadfile($state, 'tools/verify.lua')
    if ($result -eq 0) { $result = [DuoLua]::lua_pcall($state, 0, 0, 0) }
    if ($result -ne 0) { throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([DuoLua]::lua_tolstring($state, -1, [IntPtr]::Zero)) }
} finally { [DuoLua]::lua_close($state) }
