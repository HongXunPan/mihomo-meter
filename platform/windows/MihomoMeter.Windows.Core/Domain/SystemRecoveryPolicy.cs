namespace MihomoMeter.Windows.Core.Domain;

public enum SystemEnvironmentBlocker
{
    Sleep,
    InactiveSession,
    NetworkUnavailable,
}

public enum SystemRecoveryAction
{
    Pause,
    Resume,
}

public sealed class SystemRecoveryPolicy
{
    private readonly HashSet<SystemEnvironmentBlocker> _blockers = [];

    public bool IsAvailable => _blockers.Count == 0;

    public SystemRecoveryAction? Update(
        SystemEnvironmentBlocker blocker,
        bool isBlocked)
    {
        var wasAvailable = IsAvailable;
        if (isBlocked)
        {
            _blockers.Add(blocker);
        }
        else
        {
            _blockers.Remove(blocker);
        }

        if (wasAvailable == IsAvailable)
        {
            return null;
        }

        return IsAvailable
            ? SystemRecoveryAction.Resume
            : SystemRecoveryAction.Pause;
    }
}
