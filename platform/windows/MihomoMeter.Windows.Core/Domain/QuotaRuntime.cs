namespace MihomoMeter.Windows.Core.Domain;

public sealed record RuntimeQuotaCandidate(
    string SourceKey,
    DateTimeOffset? SourceUpdatedAt,
    QuotaTraffic Traffic,
    DateTimeOffset? ExpireAt);

public enum RuntimeQuotaCandidateSelectionKind
{
    None,
    Single,
    Multiple,
}

public sealed record RuntimeQuotaCandidateSelection(
    RuntimeQuotaCandidateSelectionKind Kind,
    RuntimeQuotaCandidate? Candidate,
    int CandidateCount)
{
    public static RuntimeQuotaCandidateSelection From(
        IReadOnlyList<RuntimeQuotaCandidate> candidates)
    {
        return candidates.Count switch
        {
            0 => new RuntimeQuotaCandidateSelection(
                RuntimeQuotaCandidateSelectionKind.None,
                null,
                0),
            1 => new RuntimeQuotaCandidateSelection(
                RuntimeQuotaCandidateSelectionKind.Single,
                candidates[0],
                1),
            _ => new RuntimeQuotaCandidateSelection(
                RuntimeQuotaCandidateSelectionKind.Multiple,
                null,
                candidates.Count),
        };
    }
}

public sealed record ActiveQuotaQueryResult(
    QuotaTraffic Traffic,
    DateTimeOffset? ExpireAt);

public enum ActiveQuotaQueryFailureCategory
{
    InsecureUrl,
    NoProxy,
    InsecureRedirect,
    HttpStatus,
    MissingHeader,
    InvalidHeader,
    Timeout,
    Network,
}

public sealed class ActiveQuotaQueryException : Exception
{
    public ActiveQuotaQueryException(
        ActiveQuotaQueryFailureCategory category,
        int? statusCode = null)
        : base(BuildMessage(category, statusCode))
    {
        Category = category;
        StatusCode = statusCode;
    }

    public ActiveQuotaQueryFailureCategory Category { get; }

    public int? StatusCode { get; }

    public bool IsCommunicationFailure => Category is
        ActiveQuotaQueryFailureCategory.Timeout or ActiveQuotaQueryFailureCategory.Network;

    private static string BuildMessage(
        ActiveQuotaQueryFailureCategory category,
        int? statusCode)
    {
        return category switch
        {
            ActiveQuotaQueryFailureCategory.InsecureUrl => "只支持通过 HTTPS 查询订阅配额。",
            ActiveQuotaQueryFailureCategory.NoProxy => "当前 Mihomo 没有可用的本地代理端口。",
            ActiveQuotaQueryFailureCategory.InsecureRedirect => "订阅查询重定向到了非 HTTPS 地址。",
            ActiveQuotaQueryFailureCategory.HttpStatus => $"机场返回异常状态（HTTP {statusCode}）。",
            ActiveQuotaQueryFailureCategory.MissingHeader => "机场响应未包含有效配额信息。",
            ActiveQuotaQueryFailureCategory.InvalidHeader => "机场返回的配额格式暂不受支持。",
            ActiveQuotaQueryFailureCategory.Timeout => "通过 Mihomo 查询订阅配额超时。",
            _ => "通过 Mihomo 查询订阅配额失败。",
        };
    }
}
