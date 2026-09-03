using System.ComponentModel;
using System.Runtime.InteropServices;
using GTAControlCore.Windows;

namespace GTABridge.Windows.Game;

internal sealed class TrainerInputInjector(ForegroundGameGuard foregroundGuard)
{
    public async Task InjectAsync(TrainerCommand command, CancellationToken cancellationToken = default)
    {
        foregroundGuard.Validate();
        var virtualKey = TrainerKeyMapping.VirtualKey(command);
        Send(virtualKey, keyUp: false);
        try
        {
            await Task.Delay(60, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            Send(virtualKey, keyUp: true);
        }
    }

    private static void Send(ushort virtualKey, bool keyUp)
    {
        var input = new INPUT
        {
            Type = 1,
            Data = new INPUTUNION
            {
                Keyboard = new KEYBDINPUT
                {
                    VirtualKey = virtualKey,
                    Flags = keyUp ? 0x0002u : 0,
                },
            },
        };
        if (SendInput(1, [input], Marshal.SizeOf<INPUT>()) != 1)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows non ha inviato il tasto a GTA V.");
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint Type;
        public INPUTUNION Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION
    {
        [FieldOffset(0)] public KEYBDINPUT Keyboard;
        [FieldOffset(0)] public MOUSEINPUT Mouse;
        [FieldOffset(0)] public HARDWAREINPUT Hardware;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public UIntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint Message;
        public ushort ParameterLow;
        public ushort ParameterHigh;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, INPUT[] inputs, int inputSize);
}

internal static class TrainerKeyMapping
{
    public static ushort VirtualKey(TrainerCommand command) => command switch
    {
        TrainerCommand.ToggleTrainer => 0x73,
        TrainerCommand.MoveUp => 0x68,
        TrainerCommand.MoveDown => 0x62,
        TrainerCommand.MoveLeft => 0x64,
        TrainerCommand.MoveRight => 0x66,
        TrainerCommand.Select => 0x65,
        TrainerCommand.Back => 0x08,
        TrainerCommand.NumpadBack => 0x60,
        TrainerCommand.VehicleBoostUp => 0x69,
        TrainerCommand.VehicleBoostDown => 0x63,
        TrainerCommand.VehicleRockets => 0x6B,
        _ => throw new ArgumentOutOfRangeException(nameof(command)),
    };
}
