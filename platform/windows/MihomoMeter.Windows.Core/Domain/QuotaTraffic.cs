namespace MihomoMeter.Windows.Core.Domain;

public readonly record struct QuotaTraffic
{
    public QuotaTraffic(ulong uploadBytes, ulong downloadBytes, ulong totalBytes)
    {
        if (totalBytes == 0)
        {
            throw new QuotaDomainException("订阅总额度必须大于零。");
        }

        if (uploadBytes > long.MaxValue
            || downloadBytes > long.MaxValue
            || totalBytes > long.MaxValue)
        {
            throw new QuotaDomainException("订阅配额超出本地账本范围。");
        }

        ulong usedBytes;
        try
        {
            usedBytes = checked(uploadBytes + downloadBytes);
        }
        catch (OverflowException exception)
        {
            throw new QuotaDomainException("订阅累计用量发生溢出。", exception);
        }

        if (usedBytes > long.MaxValue)
        {
            throw new QuotaDomainException("订阅累计用量超出本地账本范围。");
        }

        UploadBytes = uploadBytes;
        DownloadBytes = downloadBytes;
        TotalBytes = totalBytes;
        UsedBytes = usedBytes;
        RemainingBytes = totalBytes > usedBytes ? totalBytes - usedBytes : 0;
    }

    public ulong UploadBytes { get; }

    public ulong DownloadBytes { get; }

    public ulong TotalBytes { get; }

    public ulong UsedBytes { get; }

    public ulong RemainingBytes { get; }

    public bool IsOverQuota => UsedBytes > TotalBytes;
}

public sealed class QuotaDomainException : Exception
{
    public QuotaDomainException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
