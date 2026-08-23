namespace MihomoMeter.Windows.Core.Domain;

public enum CrashRecoveryStartupDisposition
{
    RegularLaunch,
    RecoveryAllowed,
    RecoverySuppressed,
    RecoveryArgumentInvalid,
}

public sealed record CrashRecoveryRestartState(
    string? PendingToken,
    DateTimeOffset? PendingRegisteredAtUtc,
    DateTimeOffset? LastRecoveryStartedAtUtc)
{
    public static CrashRecoveryRestartState Empty { get; } = new(null, null, null);
}

public sealed record CrashRecoveryStartupDecision(
    CrashRecoveryStartupDisposition Disposition,
    CrashRecoveryRestartState State);

public static class CrashRecoveryRestartPolicy
{
    public const string RecoveryArgumentPrefix = "--system-recovery-restart=";

    public static TimeSpan RestartWindow { get; } = TimeSpan.FromMinutes(10);

    public static TimeSpan PendingTokenLifetime { get; } = TimeSpan.FromMinutes(30);

    public static bool HasRecoveryArgument(IEnumerable<string> arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        return arguments.Any(IsRecoveryArgument);
    }

    public static CrashRecoveryStartupDecision EvaluateStartup(
        IEnumerable<string> arguments,
        CrashRecoveryRestartState state,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        ArgumentNullException.ThrowIfNull(state);

        var recoveryArguments = arguments
            .Where(IsRecoveryArgument)
            .ToArray();
        if (recoveryArguments.Length == 0)
        {
            return new CrashRecoveryStartupDecision(
                CrashRecoveryStartupDisposition.RegularLaunch,
                state);
        }

        var consumedState = state with
        {
            PendingToken = null,
            PendingRegisteredAtUtc = null,
        };
        if (recoveryArguments.Length != 1
            || !TryParseToken(recoveryArguments[0], out var token)
            || !string.Equals(token, state.PendingToken, StringComparison.Ordinal)
            || state.PendingRegisteredAtUtc is not { } registeredAt
            || registeredAt > now
            || now - registeredAt > PendingTokenLifetime)
        {
            return new CrashRecoveryStartupDecision(
                CrashRecoveryStartupDisposition.RecoveryArgumentInvalid,
                consumedState);
        }

        if (RegistrationDelay(state, now) > TimeSpan.Zero)
        {
            return new CrashRecoveryStartupDecision(
                CrashRecoveryStartupDisposition.RecoverySuppressed,
                consumedState);
        }

        return new CrashRecoveryStartupDecision(
            CrashRecoveryStartupDisposition.RecoveryAllowed,
            consumedState with { LastRecoveryStartedAtUtc = now });
    }

    public static CrashRecoveryRestartState PrepareRegistration(
        CrashRecoveryRestartState state,
        DateTimeOffset now,
        string token)
    {
        ArgumentNullException.ThrowIfNull(state);
        if (!Guid.TryParseExact(token, "N", out _))
        {
            throw new ArgumentException("恢复重启令牌格式无效。", nameof(token));
        }

        return state with
        {
            PendingToken = token,
            PendingRegisteredAtUtc = now,
        };
    }

    public static TimeSpan RegistrationDelay(
        CrashRecoveryRestartState state,
        DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(state);
        if (state.LastRecoveryStartedAtUtc is not { } lastRecovery)
        {
            return TimeSpan.Zero;
        }

        if (lastRecovery > now)
        {
            return RestartWindow;
        }

        var elapsed = now - lastRecovery;
        return elapsed < RestartWindow
            ? RestartWindow - elapsed
            : TimeSpan.Zero;
    }

    private static bool IsRecoveryArgument(string argument)
    {
        return argument.StartsWith(RecoveryArgumentPrefix, StringComparison.Ordinal);
    }

    private static bool TryParseToken(string argument, out string token)
    {
        token = argument[RecoveryArgumentPrefix.Length..];
        return Guid.TryParseExact(token, "N", out _);
    }
}
