using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;

namespace MihomoMeter.Windows.App.Infrastructure.Credentials;

internal sealed class CredentialManagerBlobStore
{
    private const uint CredentialTypeGeneric = 1;
    private const uint CredentialPersistLocalMachine = 2;
    private const int ErrorNotFound = 1168;
    private const int MaximumCredentialBlobSize = 2_560;
    private readonly string _targetName;

    public CredentialManagerBlobStore(string targetName)
    {
        _targetName = targetName;
    }

    public byte[]? Load()
    {
        if (!CredRead(_targetName, CredentialTypeGeneric, 0, out var credentialPointer))
        {
            var error = Marshal.GetLastPInvokeError();
            if (error == ErrorNotFound)
            {
                return null;
            }

            throw new CredentialManagerException("读取", error);
        }

        try
        {
            var credential = Marshal.PtrToStructure<NativeCredential>(credentialPointer);
            if (credential.CredentialBlobSize == 0 || credential.CredentialBlob == 0)
            {
                return null;
            }

            if (credential.CredentialBlobSize > MaximumCredentialBlobSize)
            {
                throw new CredentialManagerException("读取", message: "凭据长度超过系统限制。");
            }

            var data = new byte[(int)credential.CredentialBlobSize];
            Marshal.Copy(credential.CredentialBlob, data, 0, data.Length);
            return data;
        }
        finally
        {
            CredFree(credentialPointer);
        }
    }

    public void Save(ReadOnlySpan<byte> value)
    {
        if (value.Length == 0 || value.Length > MaximumCredentialBlobSize)
        {
            throw new CredentialManagerException("保存", message: "凭据长度无效。");
        }

        var data = value.ToArray();
        var targetPointer = Marshal.StringToCoTaskMemUni(_targetName);
        var blobPointer = Marshal.AllocCoTaskMem(data.Length);
        try
        {
            Marshal.Copy(data, 0, blobPointer, data.Length);
            var credential = new NativeCredential
            {
                Type = CredentialTypeGeneric,
                TargetName = targetPointer,
                CredentialBlobSize = (uint)data.Length,
                CredentialBlob = blobPointer,
                Persist = CredentialPersistLocalMachine,
            };
            if (!CredWrite(ref credential, 0))
            {
                throw new CredentialManagerException("保存", Marshal.GetLastPInvokeError());
            }
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
            ZeroNativeBuffer(blobPointer, value.Length);
            Marshal.FreeCoTaskMem(blobPointer);
            Marshal.FreeCoTaskMem(targetPointer);
        }
    }

    public void Delete()
    {
        if (CredDelete(_targetName, CredentialTypeGeneric, 0))
        {
            return;
        }

        var error = Marshal.GetLastPInvokeError();
        if (error != ErrorNotFound)
        {
            throw new CredentialManagerException("删除", error);
        }
    }

    private static void ZeroNativeBuffer(nint pointer, int length)
    {
        for (var index = 0; index < length; index += 1)
        {
            Marshal.WriteByte(pointer, index, 0);
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeCredential
    {
        public uint Flags;
        public uint Type;
        public nint TargetName;
        public nint Comment;
        public FILETIME LastWritten;
        public uint CredentialBlobSize;
        public nint CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public nint Attributes;
        public nint TargetAlias;
        public nint UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredRead(
        string target,
        uint type,
        uint flags,
        out nint credential);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredWrite(ref NativeCredential credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(nint buffer);
}
