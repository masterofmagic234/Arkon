#!/usr/bin/env python3
"""CI-only WGL diagnostics. Never changes or starts the shipping game.

Each child uses a fresh process so a previously loaded OpenGL DLL cannot affect
the next experiment. Godot-order follows official 4.7.2's two GDI pixel-format
calls before its generic LoadLibraryW. Explicit-first loads the supplied Mesa
DLL by absolute path first. The latter is a diagnostic, not a game workaround.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import traceback


class PixelFormat(ctypes.Structure):
    # Fixed-width Win32 fields also let layout validation run on CI Linux.
    _fields_ = [('nSize', ctypes.c_uint16), ('nVersion', ctypes.c_uint16),
                ('dwFlags', ctypes.c_uint32)] + [
        (name, ctypes.c_ubyte) for name in (
            'iPixelType', 'cColorBits', 'cRedBits', 'cRedShift', 'cGreenBits',
            'cGreenShift', 'cBlueBits', 'cBlueShift', 'cAlphaBits', 'cAlphaShift',
            'cAccumBits', 'cAccumRedBits', 'cAccumGreenBits', 'cAccumBlueBits',
            'cAccumAlphaBits', 'cDepthBits', 'cStencilBits', 'cAuxBuffers',
            'iLayerType', 'bReserved')
    ] + [('dwLayerMask', ctypes.c_uint32), ('dwVisibleMask', ctypes.c_uint32),
         ('dwDamageMask', ctypes.c_uint32)]


def save(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def run_child(args: argparse.Namespace) -> int:
    report = {'mode': args.mode, 'diagnostic_only': True, 'steps': [], 'modules': [],
              'driver': str(args.driver), 'process_bits': ctypes.sizeof(ctypes.c_void_p) * 8,
              'environment': {name: os.environ.get(name) for name in (
                  'GALLIUM_DRIVER', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS',
                  'MESA_GL_VERSION_OVERRIDE', 'MESA_GLSL_VERSION_OVERRIDE')},
              'result': 'INCOMPLETE', 'first_failed_stage': None}
    user = gdi = kernel = gl = None
    hwnd = dc = legacy = core = None
    callback = None
    class_name = 'AcornHunterWglDiagnostic_' + str(os.getpid())

    def step(name: str, result, success: bool = True, error_code: int | None = None, **details) -> None:
        report['steps'].append({'stage': name, 'result': result, 'success': bool(success),
                                'last_error': ctypes.get_last_error() if error_code is None else error_code,
                                **details})
        if not success and report['first_failed_stage'] is None:
            report['first_failed_stage'] = name
        save(args.report, report)

    def bind(library, name, arguments, result):
        function = getattr(library, name)
        function.argtypes, function.restype = arguments, result
        return function

    def modules(label: str) -> None:
        capacity = 512
        handles = (wintypes.HMODULE * capacity)()
        needed = wintypes.DWORD()
        current = kernel.GetCurrentProcess()
        ok = kernel.K32EnumProcessModulesEx(current, handles, ctypes.sizeof(handles),
                                           ctypes.byref(needed), 3)
        rows = []
        if ok:
            for handle in handles[:min(capacity, needed.value // ctypes.sizeof(wintypes.HMODULE))]:
                path = ctypes.create_unicode_buffer(32768)
                if kernel.K32GetModuleFileNameExW(current, handle, path, len(path)):
                    rows.append(path.value)
        report['modules'].append({'stage': label, 'success': bool(ok), 'paths': rows})
        save(args.report, report)

    def load_gl() -> None:
        nonlocal gl
        requested = str(args.driver) if args.mode == 'explicit-first' else 'opengl32.dll'
        ctypes.set_last_error(0)
        handle = kernel.LoadLibraryW(requested)
        step('LoadLibraryW', int(handle or 0), bool(handle), requested=requested)
        if not handle:
            raise RuntimeError('OpenGL DLL could not be loaded')
        path = ctypes.create_unicode_buffer(32768)
        kernel.GetModuleFileNameW(handle, path, len(path))
        report['loaded_opengl_path'] = path.value
        report['loaded_requested_mesa'] = os.path.normcase(path.value) == os.path.normcase(str(args.driver))
        gl = ctypes.WinDLL(path.value or requested, handle=handle, use_last_error=True)
        bind(gl, 'wglCreateContext', [wintypes.HDC], ctypes.c_void_p)
        bind(gl, 'wglMakeCurrent', [wintypes.HDC, ctypes.c_void_p], wintypes.BOOL)
        bind(gl, 'wglDeleteContext', [ctypes.c_void_p], wintypes.BOOL)
        bind(gl, 'wglGetProcAddress', [ctypes.c_char_p], ctypes.c_void_p)
        bind(gl, 'glGetString', [ctypes.c_uint], ctypes.c_char_p)
        modules('after_LoadLibraryW')

    def gl_strings() -> dict:
        return {name: (gl.glGetString(token) or b'').decode('utf-8', errors='replace')
                for name, token in [('vendor', 0x1F00), ('renderer', 0x1F01),
                                    ('version', 0x1F02), ('glsl', 0x8B8C)]}

    try:
        if os.name != 'nt' or ctypes.sizeof(ctypes.c_void_p) != 8:
            raise RuntimeError('This diagnostic requires actual x64 Windows Python')
        if ctypes.sizeof(PixelFormat) != 40:
            raise RuntimeError('Incorrect PIXELFORMATDESCRIPTOR layout')
        user = ctypes.WinDLL('user32', use_last_error=True)
        gdi = ctypes.WinDLL('gdi32', use_last_error=True)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        pointer = ctypes.c_void_p
        callback_type = ctypes.WINFUNCTYPE(ctypes.c_ssize_t, wintypes.HWND,
                                          wintypes.UINT, ctypes.c_size_t, ctypes.c_ssize_t)

        class WindowClass(ctypes.Structure):
            _fields_ = [('style', wintypes.UINT), ('lpfnWndProc', callback_type),
                        ('cbClsExtra', ctypes.c_int), ('cbWndExtra', ctypes.c_int),
                        ('hInstance', wintypes.HINSTANCE), ('hIcon', wintypes.HICON),
                        ('hCursor', wintypes.HANDLE), ('hbrBackground', wintypes.HBRUSH),
                        ('lpszMenuName', wintypes.LPCWSTR), ('lpszClassName', wintypes.LPCWSTR)]

        definitions = [
            (kernel, 'SetErrorMode', [wintypes.UINT], wintypes.UINT),
            (kernel, 'SetDllDirectoryW', [wintypes.LPCWSTR], wintypes.BOOL),
            (kernel, 'LoadLibraryW', [wintypes.LPCWSTR], wintypes.HMODULE),
            (kernel, 'GetModuleFileNameW', [wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD], wintypes.DWORD),
            (kernel, 'GetModuleHandleW', [wintypes.LPCWSTR], wintypes.HMODULE),
            (kernel, 'GetCurrentProcess', [], wintypes.HANDLE),
            (kernel, 'K32EnumProcessModulesEx', [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE),
                                               wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.DWORD], wintypes.BOOL),
            (kernel, 'K32GetModuleFileNameExW', [wintypes.HANDLE, wintypes.HMODULE, wintypes.LPWSTR,
                                              wintypes.DWORD], wintypes.DWORD),
            (user, 'DefWindowProcW', [wintypes.HWND, wintypes.UINT, ctypes.c_size_t, ctypes.c_ssize_t], ctypes.c_ssize_t),
            (user, 'RegisterClassW', [ctypes.POINTER(WindowClass)], wintypes.ATOM),
            (user, 'UnregisterClassW', [wintypes.LPCWSTR, wintypes.HINSTANCE], wintypes.BOOL),
            (user, 'CreateWindowExW', [wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
                                      ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                      wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, pointer], wintypes.HWND),
            (user, 'DestroyWindow', [wintypes.HWND], wintypes.BOOL),
            (user, 'GetDC', [wintypes.HWND], wintypes.HDC),
            (user, 'ReleaseDC', [wintypes.HWND, wintypes.HDC], ctypes.c_int),
            (gdi, 'ChoosePixelFormat', [wintypes.HDC, ctypes.POINTER(PixelFormat)], ctypes.c_int),
            (gdi, 'SetPixelFormat', [wintypes.HDC, ctypes.c_int, ctypes.POINTER(PixelFormat)], wintypes.BOOL),
            (gdi, 'GetPixelFormat', [wintypes.HDC], ctypes.c_int),
        ]
        for library, name, arguments, result in definitions:
            bind(library, name, arguments, result)
        kernel.SetErrorMode(0x0001 | 0x0002 | 0x8000)
        # Python lives elsewhere. This supplies the test DLL/dependency folder;
        # unlike the actual game process, it is not the executable directory.
        ctypes.set_last_error(0)
        directory_set = bool(kernel.SetDllDirectoryW(str(args.driver.parent)))
        step('SetDllDirectoryW', directory_set, directory_set)
        modules('before_pixel_format_or_OpenGL_load')
        if args.mode == 'explicit-first':
            load_gl()
        callback = callback_type(lambda window, message, wparam, lparam:
                                 user.DefWindowProcW(window, message, wparam, lparam))
        instance = kernel.GetModuleHandleW(None)
        window_class = WindowClass(style=0x0020, lpfnWndProc=callback,
                                   hInstance=instance, lpszClassName=class_name)  # CS_OWNDC
        atom = user.RegisterClassW(ctypes.byref(window_class))
        step('RegisterClassW', int(atom), bool(atom))
        if not atom:
            raise RuntimeError('Window class registration failed')
        hwnd = user.CreateWindowExW(0, class_name, 'CI WGL diagnostic', 0x00CF0000 | 0x06000000,
                                    0, 0, 100, 100, None, None, instance, None)
        step('CreateWindowExW_hidden', int(hwnd or 0), bool(hwnd))
        if not hwnd:
            raise RuntimeError('Hidden window creation failed')
        dc = user.GetDC(hwnd)
        step('GetDC', int(dc or 0), bool(dc))
        if not dc:
            raise RuntimeError('Device context creation failed')
        pfd = PixelFormat(nSize=ctypes.sizeof(PixelFormat), nVersion=1,
                          dwFlags=0x00000004 | 0x00000020 | 0x00000001,
                          iPixelType=0, cColorBits=24, cDepthBits=24, iLayerType=0)
        # Exact duplicated Godot 4.7.2 _configure_pixel_format sequence.
        # Continue after a failed step only to gather diagnostic evidence.
        for attempt in (1, 2):
            ctypes.set_last_error(0)
            pixel = gdi.ChoosePixelFormat(dc, ctypes.byref(pfd))
            step('ChoosePixelFormat_' + str(attempt), pixel, pixel > 0)
            ctypes.set_last_error(0)
            success = bool(gdi.SetPixelFormat(dc, pixel, ctypes.byref(pfd))) if pixel else False
            error_code = ctypes.get_last_error()
            step('SetPixelFormat_' + str(attempt), success, success,
                 error_code=error_code, selected=pixel, current=gdi.GetPixelFormat(dc))
            modules('after_pixel_format_' + str(attempt))
        if args.mode == 'godot-order':
            load_gl()
        ctypes.set_last_error(0)
        legacy = gl.wglCreateContext(dc)
        step('wglCreateContext', int(legacy or 0), bool(legacy))
        if not legacy:
            raise RuntimeError('Legacy WGL context creation failed')
        ctypes.set_last_error(0)
        current = bool(gl.wglMakeCurrent(dc, legacy))
        step('wglMakeCurrent_legacy', current, current)
        if not current:
            raise RuntimeError('Legacy WGL context activation failed')
        report['legacy_gl'] = gl_strings()
        ctypes.set_last_error(0)
        address = gl.wglGetProcAddress(b'wglCreateContextAttribsARB')
        valid = bool(address) and address not in (1, 2, 3, ctypes.c_void_p(-1).value)
        step('wglGetProcAddress_create_attribs', int(address or 0), valid)
        if not valid:
            raise RuntimeError('WGL_ARB_create_context entry point is unavailable')
        create_attribs = ctypes.WINFUNCTYPE(pointer, wintypes.HDC, pointer,
                                           ctypes.POINTER(ctypes.c_int))(address)
        attributes = (ctypes.c_int * 9)(0x2091, 3, 0x2092, 3, 0x9126, 1, 0x2094, 2, 0)
        ctypes.set_last_error(0)
        core = create_attribs(dc, None, attributes)
        step('wglCreateContextAttribsARB_3_3_core_forward', int(core or 0), bool(core))
        if not core:
            raise RuntimeError('OpenGL 3.3 forward-compatible core context creation failed')
        gl.wglMakeCurrent(dc, None)
        gl.wglDeleteContext(legacy)
        legacy = None
        ctypes.set_last_error(0)
        current = bool(gl.wglMakeCurrent(dc, core))
        step('wglMakeCurrent_core', current, current)
        if not current:
            raise RuntimeError('OpenGL 3.3 core context activation failed')
        report['core_gl'] = gl_strings()
        report['result'] = 'PASS' if report['first_failed_stage'] is None else 'FAILED_STAGE_BUT_CORE_CREATED'
    except Exception as error:
        report['exception'] = str(error)
        report['exception_type'] = type(error).__name__
        if report['first_failed_stage'] is None:
            report['first_failed_stage'] = 'probe_exception:' + type(error).__name__
        report['traceback'] = traceback.format_exc()
        report['result'] = 'FAIL'
    finally:
        modules_available = kernel is not None and hasattr(kernel, 'K32EnumProcessModulesEx')
        if modules_available:
            try:
                modules('final')
            except Exception as error:
                report['module_snapshot_error'] = str(error)
        if gl is not None:
            try:
                gl.wglMakeCurrent(dc, None)
                for context in (core, legacy):
                    if context:
                        gl.wglDeleteContext(context)
            except Exception as error:
                report['context_cleanup_error'] = str(error)
        if user is not None:
            if dc and hwnd:
                user.ReleaseDC(hwnd, dc)
            if hwnd:
                user.DestroyWindow(hwnd)
            if kernel is not None:
                user.UnregisterClassW(class_name, kernel.GetModuleHandleW(None))
        save(args.report, report)
    return 0 if report['result'] == 'PASS' else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--timeout', type=float, default=35)
    parser.add_argument('--mode', choices=('godot-order', 'explicit-first'), help=argparse.SUPPRESS)
    parser.add_argument('--report', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    args.driver = args.driver.resolve(strict=True)
    if args.mode:
        if args.report is None:
            parser.error('--report is required in child mode')
        return run_child(args)
    if args.output is None:
        parser.error('--output is required')
    if os.name != 'nt':
        parser.error('WGL diagnostics require actual Windows')
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {'diagnostic_only': True, 'game_started': False, 'driver': str(args.driver),
               'driver_sha256': hashlib.sha256(args.driver.read_bytes()).hexdigest(),
               'source': 'Godot 4.7.2 platform/windows/gl_manager_windows_native.cpp:312-444',
               'scope': 'Hidden-window WGL reproduction in separate Python processes; canonical game native tests remain mandatory.',
               'children': []}
    environment = dict(os.environ)
    environment.update({'GALLIUM_DRIVER': 'llvmpipe', 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '4'})
    summary['child_environment'] = {name: environment[name] for name in ('GALLIUM_DRIVER', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS')}
    for mode in ('godot-order', 'explicit-first'):
        command = [sys.executable, str(Path(__file__).resolve()), '--driver', str(args.driver),
                   '--mode', mode, '--report', str(args.output / (mode + '.json'))]
        started = time.monotonic()
        row = {'mode': mode, 'command': command}
        try:
            completed = subprocess.run(command, capture_output=True, timeout=args.timeout, check=False, env=environment)
            row['exit_code'] = completed.returncode
            (args.output / (mode + '.stdout.txt')).write_bytes(completed.stdout)
            (args.output / (mode + '.stderr.txt')).write_bytes(completed.stderr)
        except subprocess.TimeoutExpired as error:
            row['timed_out'] = True
            (args.output / (mode + '.stdout.txt')).write_bytes(error.stdout or b'')
            (args.output / (mode + '.stderr.txt')).write_bytes(error.stderr or b'')
        row['elapsed_seconds'] = round(time.monotonic() - started, 3)
        report_file = args.output / (mode + '.json')
        if report_file.is_file():
            child_report = json.loads(report_file.read_text(encoding='utf-8'))
            row['last_reported_result'] = child_report.get('result')
            row['first_failed_stage'] = child_report.get('first_failed_stage')
            row['loaded_opengl_path'] = child_report.get('loaded_opengl_path')
            row['core_gl'] = child_report.get('core_gl')
        summary['children'].append(row)
        save(args.output / 'summary.json', summary)
    print(json.dumps(summary, indent=2))
    # A WGL failure is evidence, not permission to skip the strict game tests.
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
