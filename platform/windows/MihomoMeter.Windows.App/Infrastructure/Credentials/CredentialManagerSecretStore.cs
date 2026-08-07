using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;
using System.Text;
using MihomoMeter.Windows.Core.Application;

namespace MihomoMeter.Windows.App.Infrastructure.Credentials;

internal sealed class CredentialManagerSecretStore : IControllerSecretStore
{
    internal const string TargetName = "com.HongXunPan.MihomoMeter.controller";
    private const uint CredentialTypeGeneric = 1;
    private const uint CredentialPersistLocalMachine = 2;
    private const int ErrorNotFound = 1168;
    private const int MaximumCredentialBlobSize = 2_560;
    private static readonly UTF8Encoding SecretEncoding = new(false, true);

    public Task<string?> LoadAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!CredRead(TargetName, CredentialTypeGeneric, 0, out var credentialPointer))
        {
            var error = Marshal.GetLastPInvokeError();
            if (error == ErrorNotFound)
            {
                return Task.FromResult<string?>(null);
            }

            throw new CredentialManagerException("读取", error);
        }

        try
        {
            var credential = Marshal.PtrToStructure<NativeCredential>(credentialPointer);
            if (credential.CredentialBlobSize == 0 || credential.CredentialBlob == 0)
            {
                return Task.FromResult<string?>(null);
            }

            if (credential.CredentialBlobSize > MaximumCredentialBlobSize)
            {
                throw new CredentialManagerException("读取", message: "访问密钥长度超过系统限制。");
            }

            var data = new byte[(int)credential.CredentialBlobSize];
            try
            {
                Marshal.Copy(credential.CredentialBlob, data, 0, data.Length);
                return Task.FromResult<string?>(SecretEncoding.GetString(data));
            }
            catch (DecoderFallbackException exception)
            {
                throw new CredentialManagerException("解码", innerException: exception);
            }
            finally
            {
                CryptographicOperations.ZeroMemory(data);
            }
        }
        finally
        {
            CredFree(credentialPointer);
        }
    }

    public Task SaveAsync(string secret, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (secret.Length == 0)
        {
            return DeleteAsync(cancellationToken);
        }

        var data = SecretEncoding.GetBytes(secret);
        if (data.Length > MaximumCredentialBlobSize)
        {
            CryptographicOperations.ZeroMemory(data);
            throw new CredentialManagerException("保存", message: "访问密钥长度超过系统限制。");
        }

        var targetPointer = Marshal.StringToCoTaskMemUni(TargetName);
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

            return Task.CompletedTask;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(data);
            ZeroNativeBuffer(blobPointer, data.Length);
            Marshal.FreeCoTaskMem(blobPointer);
            Marshal.FreeCoTaskMem(targetPointer);
        }
    }

    public Task DeleteAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (CredDelete(TargetName, CredentialTypeGeneric, 0))
        {
            return Task.CompletedTask;
        }

        var error = Marshal.GetLastPInvokeError();
        if (error == ErrorNotFound)
        {
            return Task.CompletedTask;
        }

        throw new CredentialManagerException("删除", error);
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

internal sealed class CredentialManagerException : ControllerConfigurationException
{
    public CredentialManagerException(
        string operation,
        int? errorCode = null,
        string? message = null,
        Exception? innerException = null)
        : base(
            message ?? $"Windows Credential Manager {operation}失败"
                + (errorCode is null ? "。" : $"（{errorCode}）。"),
            innerException)
    {
        ErrorCode = errorCode;
    }

    public int? ErrorCode { get; }
}
