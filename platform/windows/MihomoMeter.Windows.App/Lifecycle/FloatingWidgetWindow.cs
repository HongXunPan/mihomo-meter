using System.ComponentModel;
using System.Runtime.InteropServices;
using MihomoMeter.Windows.App.Diagnostics;
using MihomoMeter.Windows.App.Interop;
using MihomoMeter.Windows.App.Presentation;

namespace MihomoMeter.Windows.App.Lifecycle;

internal sealed class FloatingWidgetWindow : IDisposable
{
    private const uint WindowStylePopup = 0x80000000;
    private const uint WindowStyleExtendedTopmost = 0x00000008;
    private const uint WindowStyleExtendedToolWindow = 0x00000080;
    private const uint WindowStyleExtendedNoActivate = 0x08000000;
    private const uint WindowMessagePaint = 0x000F;
    private const uint WindowMessageEraseBackground = 0x0014;
    private const uint WindowMessageMouseActivate = 0x0021;
    private const uint WindowMessageDisplayChange = 0x007E;
    private const uint WindowMessageLeftButtonDown = 0x0201;
    private const uint WindowMessageLeftButtonUp = 0x0202;
    private const uint WindowMessageMouseMove = 0x0200;
    private const uint WindowMessageCaptureChanged = 0x0215;
    private const uint WindowMessageDpiChanged = 0x02E0;
    private const uint SetPositionNoSize = 0x0001;
    private const uint SetPositionNoActivate = 0x0010;
    private const uint SetPositionShowWindow = 0x0040;
    private const int MouseActivateNoActivate = 3;
    private const int ArrowCursor = 32512;
    private static readonly nint TopmostWindow = new(-1);

    private readonly Action _activateMainWindow;
    private readonly string _className;
    private readonly nint _instanceHandle;
    private readonly FloatingWidgetNativeMethods.WindowProcedure _windowProcedure;
    private nint _windowHandle;
    private FloatingWidgetPosition _position;
    private int _size;
    private bool _pointerPressed;
    private bool _dragged;
    private FloatingWidgetNativeMethods.Point _pointerOrigin;
    private FloatingWidgetPosition _windowOrigin;
    private FloatingWidgetDisplaySnapshot _snapshot;
    private bool _disposed;

    public FloatingWidgetWindow(
        FloatingWidgetPosition? initialPosition,
        Action activateMainWindow,
        FloatingWidgetDisplaySnapshot snapshot)
    {
        _activateMainWindow = activateMainWindow
            ?? throw new ArgumentNullException(nameof(activateMainWindow));
        _snapshot = snapshot ?? throw new ArgumentNullException(nameof(snapshot));
        _className = $"MihomoMeter.Windows.FloatingWidget.{Environment.ProcessId}";
        _instanceHandle = FloatingWidgetNativeMethods.GetModuleHandle(null);
        if (_instanceHandle == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        _windowProcedure = WindowProcedure;
        RegisterWindowClass();
        try
        {
            var dpi = FloatingWidgetNativeMethods.GetDpiForSystem();
            _size = FloatingWidgetPlacement.Scale(52, dpi);
            _position = FloatingWidgetPlacement.ResolveInitialPosition(
                initialPosition,
                _size,
                dpi);
            _windowHandle = FloatingWidgetNativeMethods.CreateWindowEx(
                WindowStyleExtendedTopmost
                    | WindowStyleExtendedToolWindow
                    | WindowStyleExtendedNoActivate,
                _className,
                _snapshot.AccessibleText,
                WindowStylePopup,
                _position.X,
                _position.Y,
                _size,
                _size,
                0,
                0,
                _instanceHandle,
                0);
            if (_windowHandle == 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            var windowDpi = FloatingWidgetNativeMethods.GetDpiForWindow(_windowHandle);
            _size = FloatingWidgetPlacement.Scale(52, windowDpi);
            _position = FloatingWidgetPlacement.ClampToWorkArea(_position, _size);
            FloatingWidgetPainter.ApplyRoundRegion(_windowHandle, _size);
            MoveWindow(_position, _size, SetPositionShowWindow);
            StartupConsoleReporter.Stage("floating_widget_created");
        }
        catch
        {
            Dispose();
            throw;
        }
    }

    public FloatingWidgetPosition Position => _position;

    public void UpdateSnapshot(FloatingWidgetDisplaySnapshot snapshot)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        _snapshot = snapshot ?? throw new ArgumentNullException(nameof(snapshot));
        if (!FloatingWidgetNativeMethods.SetWindowText(
                _windowHandle,
                _snapshot.AccessibleText))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        if (!FloatingWidgetNativeMethods.InvalidateRect(_windowHandle, 0, true))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        if (_windowHandle != 0)
        {
            FloatingWidgetNativeMethods.DestroyWindow(_windowHandle);
            _windowHandle = 0;
        }

        FloatingWidgetNativeMethods.UnregisterClass(_className, _instanceHandle);
        StartupConsoleReporter.Stage("floating_widget_destroyed");
    }

    private void RegisterWindowClass()
    {
        var cursor = FloatingWidgetNativeMethods.LoadCursor(0, (nint)ArrowCursor);
        if (cursor == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        var windowClass = new FloatingWidgetNativeMethods.WindowClass
        {
            Size = (uint)Marshal.SizeOf<FloatingWidgetNativeMethods.WindowClass>(),
            WindowProcedure = _windowProcedure,
            InstanceHandle = _instanceHandle,
            CursorHandle = cursor,
            ClassName = _className,
        };
        if (FloatingWidgetNativeMethods.RegisterClassEx(ref windowClass) == 0)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private nint WindowProcedure(
        nint windowHandle,
        uint message,
        nuint wordParameter,
        nint longParameter)
    {
        try
        {
            switch (message)
            {
                case WindowMessagePaint:
                    FloatingWidgetPainter.Paint(windowHandle, _size, _snapshot);
                    return 0;
                case WindowMessageEraseBackground:
                    return 1;
                case WindowMessageMouseActivate:
                    return MouseActivateNoActivate;
                case WindowMessageLeftButtonDown:
                    BeginPointerDrag(windowHandle);
                    return 0;
                case WindowMessageMouseMove:
                    ContinuePointerDrag();
                    return 0;
                case WindowMessageLeftButtonUp:
                    EndPointerDrag();
                    return 0;
                case WindowMessageCaptureChanged:
                    _pointerPressed = false;
                    return 0;
                case WindowMessageDpiChanged:
                    ApplyDpiChange(longParameter);
                    return 0;
                case WindowMessageDisplayChange:
                    ClampToVisibleWorkArea();
                    return 0;
            }
        }
        catch (Exception exception)
        {
            StartupConsoleReporter.Failure("floating_widget_message", exception);
        }

        return FloatingWidgetNativeMethods.DefWindowProc(
            windowHandle,
            message,
            wordParameter,
            longParameter);
    }

    private void BeginPointerDrag(nint windowHandle)
    {
        if (!FloatingWidgetNativeMethods.GetCursorPos(out _pointerOrigin))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }

        _windowOrigin = _position;
        _pointerPressed = true;
        _dragged = false;
        FloatingWidgetNativeMethods.SetCapture(windowHandle);
    }

    private void ContinuePointerDrag()
    {
        if (!_pointerPressed
            || !FloatingWidgetNativeMethods.GetCursorPos(out var pointer))
        {
            return;
        }

        var deltaX = pointer.X - _pointerOrigin.X;
        var deltaY = pointer.Y - _pointerOrigin.Y;
        _dragged |= Math.Abs(deltaX) >= 4 || Math.Abs(deltaY) >= 4;
        if (!_dragged)
        {
            return;
        }

        var proposed = new FloatingWidgetPosition(
            _windowOrigin.X + deltaX,
            _windowOrigin.Y + deltaY);
        _position = FloatingWidgetPlacement.ClampToWorkArea(proposed, _size);
        MoveWindow(_position, _size, SetPositionNoSize);
    }

    private void EndPointerDrag()
    {
        if (!_pointerPressed)
        {
            return;
        }

        var shouldActivate = !_dragged;
        _pointerPressed = false;
        FloatingWidgetNativeMethods.ReleaseCapture();
        if (shouldActivate)
        {
            _activateMainWindow();
        }
    }

    private void ApplyDpiChange(nint suggestedRectanglePointer)
    {
        var suggested = Marshal.PtrToStructure<FloatingWidgetNativeMethods.Rect>(
            suggestedRectanglePointer);
        var dpi = FloatingWidgetNativeMethods.GetDpiForWindow(_windowHandle);
        _size = FloatingWidgetPlacement.Scale(52, dpi);
        _position = FloatingWidgetPlacement.ClampToWorkArea(
            new FloatingWidgetPosition(suggested.Left, suggested.Top),
            _size);
        MoveWindow(_position, _size, 0);
        FloatingWidgetPainter.ApplyRoundRegion(_windowHandle, _size);
    }

    private void ClampToVisibleWorkArea()
    {
        _position = FloatingWidgetPlacement.ClampToWorkArea(_position, _size);
        MoveWindow(_position, _size, SetPositionNoSize);
    }

    private void MoveWindow(FloatingWidgetPosition position, int size, uint extraFlags)
    {
        if (!FloatingWidgetNativeMethods.SetWindowPos(
                _windowHandle,
                TopmostWindow,
                position.X,
                position.Y,
                size,
                size,
                SetPositionNoActivate | extraFlags))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }

}
