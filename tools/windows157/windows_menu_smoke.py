#!/usr/bin/env python3
"""Exercise the unchanged shipping main menu through actual Windows GUI input.

The EXE/PCK are launched normally: no project, main-pack, script or bootstrap
override. Mesa DLLs belong to the isolated CI copy, never to the download.
This checks software-rendered GUI correctness, not hardware requirements/FPS.
Only the Python standard library and Windows system APIs are required.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import traceback
import zlib


@dataclass
class Picture:
    width: int
    height: int
    rgb: bytes

    def save(self, destination: Path) -> None:
        def chunk(kind: bytes, data: bytes) -> bytes:
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF)

        stride = self.width * 3
        rows = b''.join(b'\0' + self.rgb[at:at + stride] for at in range(0, len(self.rgb), stride))
        destination.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.width, self.height, 8, 2, 0, 0, 0))
                               + chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b''))

    def pink_title_pixels(self) -> int:
        # The normal title is pink. The graphics modal's 90% shade removes
        # those bright pink pixels, giving a visible state check without hooks.
        count = 0
        for y in range(int(self.height * .12), int(self.height * .24), 2):
            for x in range(int(self.width * .25), int(self.width * .75), 2):
                at = (y * self.width + x) * 3
                r, g, b = self.rgb[at:at + 3]
                count += r > 100 and r > g * 1.15 and b > g * 1.02 and r > b
        return count

    def center_difference(self, other: Picture) -> dict[str, float]:
        if (self.width, self.height) != (other.width, other.height):
            raise RuntimeError('Menu client size changed during GUI acceptance')
        changed = total = delta = 0
        for y in range(int(self.height * .10), int(self.height * .85), 4):
            for x in range(int(self.width * .20), int(self.width * .80), 4):
                at = (y * self.width + x) * 3
                differences = [abs(self.rgb[at + channel] - other.rgb[at + channel]) for channel in range(3)]
                changed += max(differences) >= 12
                delta += sum(differences)
                total += 1
        return {'changed_fraction': changed / total, 'mean_channel_difference': delta / (total * 3)}


class Windows:
    """Typed Win32 calls; instantiated only on Windows (pure helpers test on CI Linux)."""
    def __init__(self) -> None:
        self.user = ctypes.WinDLL('user32', use_last_error=True)
        self.gdi = ctypes.WinDLL('gdi32', use_last_error=True)
        self.kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        self.callback = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        pointer = ctypes.c_void_p
        ulong_ptr = ctypes.c_size_t

        class MouseInput(ctypes.Structure):
            _fields_ = [('dx', wintypes.LONG), ('dy', wintypes.LONG), ('mouseData', wintypes.DWORD),
                        ('dwFlags', wintypes.DWORD), ('time', wintypes.DWORD), ('dwExtraInfo', ulong_ptr)]

        class KeyboardInput(ctypes.Structure):
            _fields_ = [('wVk', wintypes.WORD), ('wScan', wintypes.WORD), ('dwFlags', wintypes.DWORD),
                        ('time', wintypes.DWORD), ('dwExtraInfo', ulong_ptr)]

        class HardwareInput(ctypes.Structure):
            _fields_ = [('uMsg', wintypes.DWORD), ('wParamL', wintypes.WORD), ('wParamH', wintypes.WORD)]

        class InputUnion(ctypes.Union):
            _fields_ = [('mi', MouseInput), ('ki', KeyboardInput), ('hi', HardwareInput)]

        class Input(ctypes.Structure):
            _anonymous_ = ('data',)
            _fields_ = [('type', wintypes.DWORD), ('data', InputUnion)]

        class BitmapHeader(ctypes.Structure):
            _fields_ = [('biSize', wintypes.DWORD), ('biWidth', wintypes.LONG), ('biHeight', wintypes.LONG),
                        ('biPlanes', wintypes.WORD), ('biBitCount', wintypes.WORD), ('biCompression', wintypes.DWORD),
                        ('biSizeImage', wintypes.DWORD), ('biXPelsPerMeter', wintypes.LONG), ('biYPelsPerMeter', wintypes.LONG),
                        ('biClrUsed', wintypes.DWORD), ('biClrImportant', wintypes.DWORD)]

        self.Input, self.MouseInput, self.KeyboardInput, self.BitmapHeader = Input, MouseInput, KeyboardInput, BitmapHeader
        if ctypes.sizeof(ctypes.c_void_p) == 8 and ctypes.sizeof(Input) != 40:
            raise RuntimeError('Incorrect x64 Win32 INPUT layout')
        definitions = [
            (self.user, 'EnumWindows', [self.callback, wintypes.LPARAM], wintypes.BOOL),
            (self.user, 'GetWindowThreadProcessId', [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)], wintypes.DWORD),
            (self.user, 'IsWindowVisible', [wintypes.HWND], wintypes.BOOL),
            (self.user, 'GetWindowTextW', [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int], ctypes.c_int),
            (self.user, 'GetClassNameW', [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int], ctypes.c_int),
            (self.user, 'GetClientRect', [wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
            (self.user, 'GetWindowRect', [wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
            (self.user, 'ClientToScreen', [wintypes.HWND, ctypes.POINTER(wintypes.POINT)], wintypes.BOOL),
            (self.user, 'ShowWindow', [wintypes.HWND, ctypes.c_int], wintypes.BOOL),
            (self.user, 'SetForegroundWindow', [wintypes.HWND], wintypes.BOOL),
            (self.user, 'GetForegroundWindow', [], wintypes.HWND),
            (self.user, 'BringWindowToTop', [wintypes.HWND], wintypes.BOOL),
            (self.user, 'AttachThreadInput', [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL], wintypes.BOOL),
            (self.user, 'SetCursorPos', [ctypes.c_int, ctypes.c_int], wintypes.BOOL),
            (self.user, 'SendInput', [wintypes.UINT, ctypes.POINTER(Input), ctypes.c_int], wintypes.UINT),
            (self.user, 'GetDC', [wintypes.HWND], wintypes.HDC),
            (self.user, 'ReleaseDC', [wintypes.HWND, wintypes.HDC], ctypes.c_int),
            (self.user, 'GetSystemMetrics', [ctypes.c_int], ctypes.c_int),
            (self.gdi, 'CreateCompatibleDC', [wintypes.HDC], wintypes.HDC),
            (self.gdi, 'CreateDIBSection', [wintypes.HDC, pointer, wintypes.UINT, ctypes.POINTER(pointer), wintypes.HANDLE, wintypes.DWORD], wintypes.HBITMAP),
            (self.gdi, 'SelectObject', [wintypes.HDC, wintypes.HANDLE], wintypes.HANDLE),
            (self.gdi, 'BitBlt', [wintypes.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                               wintypes.HDC, ctypes.c_int, ctypes.c_int, wintypes.DWORD], wintypes.BOOL),
            (self.gdi, 'DeleteObject', [wintypes.HANDLE], wintypes.BOOL),
            (self.gdi, 'DeleteDC', [wintypes.HDC], wintypes.BOOL),
            (self.gdi, 'GdiFlush', [], wintypes.BOOL),
            (self.kernel, 'GetCurrentThreadId', [], wintypes.DWORD),
            (self.kernel, 'OpenProcess', [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            (self.kernel, 'CloseHandle', [wintypes.HANDLE], wintypes.BOOL),
            (self.kernel, 'K32EnumProcessModulesEx', [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE), wintypes.DWORD,
                                                  ctypes.POINTER(wintypes.DWORD), wintypes.DWORD], wintypes.BOOL),
            (self.kernel, 'K32GetModuleFileNameExW', [wintypes.HANDLE, wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD], wintypes.DWORD),
        ]
        for library, name, arguments, result in definitions:
            method = getattr(library, name)
            method.argtypes, method.restype = arguments, result
        try:
            self.user.SetProcessDpiAwarenessContext.argtypes = [pointer]
            self.user.SetProcessDpiAwarenessContext.restype = wintypes.BOOL
            self.user.SetProcessDpiAwarenessContext(pointer(-4))  # Physical screen coordinates.
        except AttributeError:
            self.user.SetProcessDPIAware()

    def find(self, pid: int) -> int | None:
        windows = []

        @self.callback
        def collect(hwnd: int, _param: int) -> bool:
            owner = wintypes.DWORD()
            self.user.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
            if owner.value == pid and self.user.IsWindowVisible(hwnd):
                rect = wintypes.RECT()
                self.user.GetClientRect(hwnd, ctypes.byref(rect))
                if rect.right >= 640 and rect.bottom >= 360:
                    windows.append((rect.right * rect.bottom, hwnd))
            return True

        if not self.user.EnumWindows(collect, 0):
            raise ctypes.WinError(ctypes.get_last_error())
        return max(windows)[1] if windows else None

    def info(self, hwnd: int) -> dict:
        title, class_name = ctypes.create_unicode_buffer(1024), ctypes.create_unicode_buffer(256)
        self.user.GetWindowTextW(hwnd, title, len(title))
        self.user.GetClassNameW(hwnd, class_name, len(class_name))
        result = {'hwnd': int(hwnd), 'title': title.value, 'class': class_name.value,
                  'visible': bool(self.user.IsWindowVisible(hwnd))}
        try:
            result['client_screen'] = list(self.bounds(hwnd))
        except OSError as error:
            result['client_bounds_error'] = str(error)
        rectangle = wintypes.RECT()
        if self.user.GetWindowRect(hwnd, ctypes.byref(rectangle)):
            result['window_screen'] = [rectangle.left, rectangle.top, rectangle.right, rectangle.bottom]
        else:
            result['window_bounds_error'] = str(ctypes.WinError(ctypes.get_last_error()))
        return result

    def all_windows(self, pid: int) -> list[dict]:
        """Include hidden/zero-size startup windows and native error dialogs."""
        rows = []

        @self.callback
        def collect(hwnd: int, _param: int) -> bool:
            owner = wintypes.DWORD()
            thread = self.user.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
            if owner.value == pid:
                row = self.info(hwnd)
                row.update({'pid': owner.value, 'thread_id': thread})
                rows.append(row)
            return True

        if not self.user.EnumWindows(collect, 0):
            raise ctypes.WinError(ctypes.get_last_error())
        return sorted(rows, key=lambda row: row['hwnd'])

    def modules(self, pid: int) -> list[dict]:
        # Reading actual loaded paths distinguishes app-local Mesa from a
        # preloaded System32 OpenGL module. This never changes DLL resolution.
        process = self.kernel.OpenProcess(0x0400 | 0x0010, False, pid)
        if not process:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            capacity = 256
            while True:
                modules = (wintypes.HMODULE * capacity)()
                needed = wintypes.DWORD()
                if not self.kernel.K32EnumProcessModulesEx(process, modules, ctypes.sizeof(modules), ctypes.byref(needed), 3):
                    raise ctypes.WinError(ctypes.get_last_error())
                if needed.value <= ctypes.sizeof(modules):
                    break
                capacity = needed.value // ctypes.sizeof(wintypes.HMODULE) + 32
            rows = []
            for module in modules[:needed.value // ctypes.sizeof(wintypes.HMODULE)]:
                path = ctypes.create_unicode_buffer(32768)
                length = self.kernel.K32GetModuleFileNameExW(process, module, path, len(path))
                row = {'handle': int(module)}
                if length:
                    row['path'] = path.value
                else:
                    row['path_error'] = str(ctypes.WinError(ctypes.get_last_error()))
                rows.append(row)
            return rows
        finally:
            self.kernel.CloseHandle(process)

    def bounds(self, hwnd: int) -> tuple[int, int, int, int]:
        rect, origin = wintypes.RECT(), wintypes.POINT(0, 0)
        if not self.user.GetClientRect(hwnd, ctypes.byref(rect)) or not self.user.ClientToScreen(hwnd, ctypes.byref(origin)):
            raise ctypes.WinError(ctypes.get_last_error())
        return origin.x, origin.y, rect.right, rect.bottom

    def foreground(self, hwnd: int) -> None:
        self.user.ShowWindow(hwnd, 9)  # SW_RESTORE
        self.user.BringWindowToTop(hwnd)
        self.user.SetForegroundWindow(hwnd)
        if self.user.GetForegroundWindow() != hwnd:
            # Foreground restrictions can apply to CI's launching PowerShell.
            # Attach only while requesting focus, then always detach.
            current = self.kernel.GetCurrentThreadId()
            foreground = self.user.GetWindowThreadProcessId(self.user.GetForegroundWindow(), None)
            target = self.user.GetWindowThreadProcessId(hwnd, None)
            attached = []
            try:
                for thread in set([foreground, target]) - set([0, current]):
                    if self.user.AttachThreadInput(current, thread, True):
                        attached.append(thread)
                self.user.BringWindowToTop(hwnd)
                self.user.SetForegroundWindow(hwnd)
            finally:
                for thread in attached:
                    self.user.AttachThreadInput(current, thread, False)
        if self.user.GetForegroundWindow() != hwnd:
            raise RuntimeError('Actual game window could not receive foreground OS input')

    def send(self, event: ctypes.Structure) -> None:
        if self.user.SendInput(1, ctypes.byref(event), ctypes.sizeof(self.Input)) != 1:
            raise ctypes.WinError(ctypes.get_last_error())

    def key(self, vk: int, pressed: bool) -> None:
        event = self.Input(type=1)
        event.ki = self.KeyboardInput(vk, 0, 0 if pressed else 2, 0, 0)
        self.send(event)

    def tap(self, vk: int) -> None:
        self.key(vk, True)
        try:
            time.sleep(.08)
        finally:
            self.key(vk, False)

    def click(self, hwnd: int) -> dict:
        self.foreground(hwnd)
        x, y, width, height = self.bounds(hwnd)
        scale = min(width / 1280, height / 720)
        point = [round(width - 128 * scale), round(height - 56 * scale)]
        if not self.user.SetCursorPos(x + point[0], y + point[1]):
            raise ctypes.WinError(ctypes.get_last_error())
        time.sleep(.15)
        event = self.Input(type=0)
        event.mi = self.MouseInput(0, 0, 0, 2, 0, 0)  # Left down.
        self.send(event)
        try:
            time.sleep(.08)
        finally:
            event.mi.dwFlags = 4  # Left up.
            self.send(event)
        return {'client': point, 'screen': [x + point[0], y + point[1]], 'input': 'SetCursorPos + SendInput'}

    def close(self, hwnd: int) -> None:
        self.foreground(hwnd)
        self.key(0x12, True)  # Alt.
        try:
            self.tap(0x73)  # F4.
        finally:
            self.key(0x12, False)

    def capture(self, hwnd: int) -> Picture:
        if self.user.GetForegroundWindow() != hwnd:
            raise RuntimeError('Foreground changed before real screen capture')
        x, y, width, height = self.bounds(hwnd)
        sx, sy, sw, sh = (self.user.GetSystemMetrics(index) for index in [76, 77, 78, 79])
        if width < 960 or height < 540 or x < sx or y < sy or x + width > sx + sw or y + height > sy + sh:
            raise RuntimeError(f'Game client must be fully visible for capture: {(x, y, width, height)} on {(sx, sy, sw, sh)}')
        return self.capture_rectangle(x, y, width, height)

    def capture_desktop(self) -> tuple[Picture, list[int]]:
        bounds = [self.user.GetSystemMetrics(index) for index in [76, 77, 78, 79]]
        return self.capture_rectangle(*bounds), bounds

    def capture_rectangle(self, x: int, y: int, width: int, height: int) -> Picture:
        if width <= 0 or height <= 0:
            raise RuntimeError(f'Invalid desktop capture dimensions: {(width, height)}')
        # Read the composited visible client. PrintWindow commonly returns a
        # blank OpenGL surface, so screen BitBlt is the acceptance source.
        screen = self.user.GetDC(None)
        memory, bitmap, previous = None, None, None
        try:
            if not screen:
                raise ctypes.WinError(ctypes.get_last_error())
            memory = self.gdi.CreateCompatibleDC(screen)
            if not memory:
                raise ctypes.WinError(ctypes.get_last_error())
            header = self.BitmapHeader()
            header.biSize, header.biWidth, header.biHeight = ctypes.sizeof(header), width, -height
            header.biPlanes, header.biBitCount = 1, 32
            bits = ctypes.c_void_p()
            bitmap = self.gdi.CreateDIBSection(screen, ctypes.byref(header), 0, ctypes.byref(bits), None, 0)
            if not bitmap or not bits.value:
                raise ctypes.WinError(ctypes.get_last_error())
            previous = self.gdi.SelectObject(memory, bitmap)
            if not self.gdi.BitBlt(memory, 0, 0, width, height, screen, x, y, 0x00CC0020 | 0x40000000):
                raise ctypes.WinError(ctypes.get_last_error())
            self.gdi.GdiFlush()
            bgra = ctypes.string_at(bits, width * height * 4)
            rgb = bytearray(width * height * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = bgra[2::4], bgra[1::4], bgra[0::4]
            return Picture(width, height, bytes(rgb))
        finally:
            if previous:
                self.gdi.SelectObject(memory, previous)
            if bitmap:
                self.gdi.DeleteObject(bitmap)
            if memory:
                self.gdi.DeleteDC(memory)
            if screen:
                self.user.ReleaseDC(None, screen)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def self_test() -> None:
    import tempfile
    picture = Picture(2, 1, bytes([255, 0, 0, 0, 255, 0]))
    with tempfile.TemporaryDirectory() as folder:
        destination = Path(folder) / 'capture.png'
        picture.save(destination)
        raw = destination.read_bytes()
        assert raw[:8] == b'\x89PNG\r\n\x1a\n'
        at, compressed = 8, b''
        while at < len(raw):
            length = struct.unpack_from('>I', raw, at)[0]
            kind, data = raw[at + 4:at + 8], raw[at + 8:at + 8 + length]
            assert struct.unpack_from('>I', raw, at + length + 8)[0] == zlib.crc32(kind + data) & 0xFFFFFFFF
            if kind == b'IDAT': compressed += data
            at += length + 12
        assert zlib.decompress(compressed) == b'\0' + picture.rgb
    reference = Picture(40, 40, bytes([250, 170, 190]) * 1600)
    assert reference.pink_title_pixels() > 0
    assert reference.center_difference(reference) == {'changed_fraction': 0.0, 'mean_channel_difference': 0.0}
    print('WINDOWS157 GUI HELPER: SELF TEST PASS')


def run(args: argparse.Namespace) -> int:
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    meta = {'result': 'FAIL', 'scope': 'Unmodified shipping main menu, actual Windows OS input and visible-screen readback; isolated Mesa software CI, not hardware FPS.',
            'physical_windows_benchmark': False, 'helper_sha256': digest(Path(__file__)), 'checks': [], 'captures': [], 'failure': None}
    process = None
    windows = None
    hwnd = None
    before = {}
    started = time.monotonic()
    deadline = started + args.timeout
    stdout_path, stderr_path, log = output / 'stdout.log', output / 'stderr.log', output / 'game.log'
    checks_by_message = {}

    def check(condition: bool, message: str) -> None:
        if message not in checks_by_message:
            checks_by_message[message] = {'pass': bool(condition), 'message': message, 'observations': 1}
            meta['checks'].append(checks_by_message[message])
        else:
            entry = checks_by_message[message]
            entry['observations'] += 1
            entry['pass'] = entry['pass'] and bool(condition)
        if not condition:
            raise RuntimeError(message)

    def observe_windows() -> list[dict]:
        rows = windows.all_windows(process.pid)
        history = meta.setdefault('window_history', [])
        elapsed = round(time.monotonic() - started, 3)
        if history and rows == history[-1]['windows']:
            history[-1]['observations'] += 1
            history[-1]['last_seen_seconds'] = elapsed
        else:
            history.append({'first_seen_seconds': elapsed, 'last_seen_seconds': elapsed, 'observations': 1, 'windows': rows})
        return rows

    def observe_modules(label: str) -> None:
        rows = windows.modules(process.pid)
        subset = [row for row in rows if any(word in row.get('path', '').lower()
                  for word in ['opengl', 'mesa', 'gallium', 'llvm', 'gdi32', 'libegl', 'libgles', 'vulkan', 'dxgi', 'd3d'])]
        meta.setdefault('module_snapshots', []).append({'phase': label, 'elapsed_seconds': round(time.monotonic() - started, 3),
                                                      'modules': rows, 'graphics_modules': subset})

    def diagnose_failure() -> None:
        if windows is None or meta.get('failure_diagnostics_collected'):
            return
        meta['failure_diagnostics_collected'] = True
        # Capture before dismissing a native error dialog or terminating the
        # owned process. Each diagnostic keeps its own error if unavailable.
        if process is not None:
            try:
                meta['failure_windows'] = observe_windows()
            except Exception as error:
                meta.setdefault('diagnostic_errors', []).append({'step': 'failure_windows', 'error': str(error)})
            try:
                observe_modules('failure_before_cleanup')
            except Exception as error:
                meta.setdefault('diagnostic_errors', []).append({'step': 'failure_modules', 'error': str(error)})
        try:
            picture, bounds = windows.capture_desktop()
            name = 'failure-desktop.png'
            picture.save(output / name)
            meta['captures'].append(name)
            meta['failure_desktop_bounds'] = bounds
        except Exception as error:
            meta.setdefault('diagnostic_errors', []).append({'step': 'failure_desktop', 'error': str(error)})

    def runtime_errors() -> list[str]:
        combined = '\n'.join(path.read_text(encoding='utf-8', errors='replace')
                             for path in [log, stdout_path, stderr_path] if path.exists())
        return re.findall(r'^.*(?:SCRIPT ERROR:|Parser Error:|Parse Error:|Shader compilation failed|Invalid (?:access|call|get|set)|Cannot open file|ERROR:).*$', combined, re.M)

    def raise_if_runtime_error() -> None:
        fatal = runtime_errors()
        if fatal:
            meta['fatal_log_lines'] = fatal
            diagnose_failure()
            raise RuntimeError('Actual Windows runtime error: ' + fatal[0])

    def capture(label: str) -> Picture:
        picture = windows.capture(hwnd)
        destination = output / (label + '.png')
        picture.save(destination)
        if destination.name not in meta['captures']:
            meta['captures'].append(destination.name)
        meta['latest_capture'] = destination.name
        return picture

    def wait_picture(label: str, accepted, seconds: float) -> Picture:
        until = min(deadline - 5, time.monotonic() + seconds)
        while time.monotonic() < until:
            raise_if_runtime_error()
            check(process.poll() is None, 'normal Windows menu process remains running')
            picture = capture(label)
            if accepted(picture):
                return picture
            time.sleep(.4)
        raise TimeoutError('Timed out waiting for visible state: ' + label)

    try:
        check(sys.platform == 'win32', 'GUI acceptance runs on actual Windows')
        exe = args.exe.resolve()
        pack = exe.with_suffix('.pck')
        check(exe.is_file() and pack.is_file(), 'actual shipping EXE and adjacent PCK exist')
        check(not (exe.parent / 'override.cfg').exists(), 'canonical menu has no acceptance override.cfg')
        check(not (exe.parent / 'project.godot').exists(), 'canonical executable directory has no loose source project')
        before = {str(path): digest(path) for path in [exe, pack]}
        meta['files_before'] = before
        windows = Windows()
        desktop = [windows.user.GetSystemMetrics(index) for index in [0, 1]]
        scale = min(1.0, (desktop[0] - 64) / 1280, (desktop[1] - 120) / 720)
        check(scale >= .75, 'interactive Windows desktop can fit at least a 960x540 client')
        resolution = [int(1280 * scale) // 2 * 2, int(720 * scale) // 2 * 2]
        meta.update({'primary_desktop': desktop, 'requested_client': resolution})
        cmd = [str(exe), '--log-file', str(log), '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
               '--rendering-driver', 'opengl3', '--resolution', f'{resolution[0]}x{resolution[1]}']
        environment = dict(os.environ)
        environment.update({'APPDATA': str(output / 'user-data'), 'LOCALAPPDATA': str(output / 'user-local-data'),
                            'GALLIUM_DRIVER': 'llvmpipe', 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '4'})
        meta.update({'command': cmd, 'cwd': str(exe.parent), 'actual_windows_executable': str(exe),
                     'environment': {key: environment[key] for key in ['APPDATA', 'LOCALAPPDATA', 'GALLIUM_DRIVER', 'LIBGL_ALWAYS_SOFTWARE', 'LP_NUM_THREADS']},
                     'capture_method': 'foreground client pixels via GDI screen BitBlt', 'input_method': 'Win32 SendInput'})
        with stdout_path.open('wb') as stdout, stderr_path.open('wb') as stderr:
            process = subprocess.Popen(cmd, cwd=exe.parent, env=environment, stdout=stdout, stderr=stderr)
            meta['pid'] = process.pid
            while time.monotonic() < min(deadline - 40, started + 120):
                raise_if_runtime_error()
                check(process.poll() is None, 'normal Windows process survives startup')
                observe_windows()
                hwnd = windows.find(process.pid)
                if hwnd:
                    break
                time.sleep(.25)
            check(hwnd is not None, 'real visible top-level window belongs to shipping process PID')
            meta['window'] = windows.info(hwnd)
            try:
                observe_modules('visible_window_ready')
            except Exception as error:
                meta.setdefault('diagnostic_errors', []).append({'step': 'visible_window_modules', 'error': str(error)})
            windows.foreground(hwnd)
            menu = wait_picture('01-menu-startup', lambda frame: frame.pink_title_pixels() >= 80, 35)
            meta['menu_title_pixels'] = menu.pink_title_pixels()
            check(True, 'normal startup renders the pink ACORN HUNTER main-menu title')
            meta['graphics_click'] = windows.click(hwnd)

            def modal_visible(frame: Picture) -> bool:
                difference = menu.center_difference(frame)
                meta['modal_difference'] = difference
                meta['modal_title_pixels'] = frame.pink_title_pixels()
                return (difference['changed_fraction'] >= .05 and difference['mean_channel_difference'] >= 3
                        and frame.pink_title_pixels() < menu.pink_title_pixels() * .2)

            wait_picture('02-graphics-open', modal_visible, 20)
            check(True, 'real OS mouse click opens and shades the graphics modal')
            windows.foreground(hwnd)
            windows.tap(0x1B)  # Escape.

            def restored(frame: Picture) -> bool:
                difference = menu.center_difference(frame)
                meta['restored_difference'] = difference
                return frame.pink_title_pixels() >= menu.pink_title_pixels() * .8 and difference['changed_fraction'] < .05

            wait_picture('03-menu-after-escape', restored, 20)
            check(True, 'real OS Escape closes graphics and restores the normal main menu')
            windows.foreground(hwnd)
            windows.tap(0x1B)
            time.sleep(.4)
            final = capture('04-menu-plain-escape')
            check(restored(final) and process.poll() is None, 'plain-menu OS Escape keeps the normal menu visible')
            windows.click(hwnd)
            wait_picture('05-graphics-after-plain-escape', modal_visible, 20)
            check(True, 'graphics still responds to a real mouse click after plain-menu Escape')
            windows.foreground(hwnd)
            windows.tap(0x1B)
            wait_picture('06-menu-before-close', restored, 20)
            windows.close(hwnd)
            meta['exit_code'] = process.wait(timeout=max(1, min(30, deadline - time.monotonic())))
            check(meta['exit_code'] == 0, 'real OS Alt+F4 exits the shipping process cleanly')
        combined = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in [log, stdout_path, stderr_path] if path.exists())
        fatal = re.findall(r'^.*(?:SCRIPT ERROR:|Parser Error:|Parse Error:|Shader compilation failed|Invalid (?:access|call|get|set)|Cannot open file|ERROR:).*$', combined, re.M)
        meta['fatal_log_lines'] = fatal
        meta['llvmpipe_in_log'] = 'llvmpipe' in combined.lower()
        meta['godot_header_in_log'] = 'Godot Engine v4.7.2' in combined
        meta['compatibility_header_in_log'] = 'OpenGL' in combined and 'Compatibility' in combined
        check(not fatal, 'normal shipping GUI logs contain no engine/script errors')
        check(meta['godot_header_in_log'] and meta['compatibility_header_in_log'], 'normal GUI logs identify actual Godot 4.7.2 Compatibility startup')
        check(meta['llvmpipe_in_log'], 'normal GUI logs confirm the isolated Mesa llvmpipe software renderer')
        after = {name: digest(Path(name)) for name in before}
        meta['files_after'] = after
        check(before == after, 'normal GUI test leaves exact shipping EXE/PCK bytes unchanged')
        check(not (exe.parent / 'override.cfg').exists(), 'normal GUI test created no bootstrap override')
        meta['result'] = 'PASS'
    except Exception as error:
        meta['failure'] = str(error)
        meta['traceback'] = traceback.format_exc()
    finally:
        if meta['result'] != 'PASS':
            diagnose_failure()
        if process is not None and process.poll() is None:
            meta['cleanup_required'] = True
            try:
                if windows is not None and hwnd is not None:
                    windows.close(hwnd)
                process.wait(timeout=5)
            except Exception:
                process.kill()
                process.wait(timeout=5)
                meta['forced_cleanup'] = True
        if process is not None:
            meta['exit_code'] = process.returncode
        if before:
            meta['files_after'] = {name: digest(Path(name)) for name in before if Path(name).is_file()}
            if meta['files_after'] != before:
                meta['result'], meta['failure'] = 'FAIL', 'EXE/PCK changed or disappeared during GUI acceptance'
        meta['elapsed_seconds'] = round(time.monotonic() - started, 3)
        meta['logs'] = {path.name: {'exists': path.exists(), 'sha256': digest(path) if path.exists() else None}
                        for path in [stdout_path, stderr_path, log]}
        meta['capture_sha256'] = {name: digest(output / name) for name in meta['captures']}
        (output / 'launch.json').write_text(json.dumps(meta, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('WINDOWS157 CANONICAL GUI: ' + meta['result'])
    if meta['failure']:
        print(meta['failure'], file=sys.stderr)
    return 0 if meta['result'] == 'PASS' else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--timeout', type=int, default=210)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if args.exe is None or args.output is None:
        parser.error('--exe and --output are required for actual Windows GUI acceptance')
    if args.timeout < 90:
        parser.error('--timeout must allow at least 90 seconds for software rendering/startup')
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
