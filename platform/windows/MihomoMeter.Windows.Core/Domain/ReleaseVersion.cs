using System.Globalization;

namespace MihomoMeter.Windows.Core.Domain;

public readonly record struct ReleaseVersion(int Major, int Minor, int Patch)
    : IComparable<ReleaseVersion>
{
    public static bool TryParse(string? value, out ReleaseVersion version)
    {
        version = default;
        if (string.IsNullOrEmpty(value))
        {
            return false;
        }

        var parts = value.Split('.');
        if (parts.Length != 3
            || !TryParsePart(parts[0], out var major)
            || !TryParsePart(parts[1], out var minor)
            || !TryParsePart(parts[2], out var patch))
        {
            return false;
        }

        version = new ReleaseVersion(major, minor, patch);
        return true;
    }

    public static ReleaseVersion FromAssemblyVersion(Version version)
    {
        ArgumentNullException.ThrowIfNull(version);
        if (version.Major < 0 || version.Minor < 0 || version.Build < 0)
        {
            throw new ArgumentException("程序集版本必须至少包含三个非负部分。", nameof(version));
        }

        return new ReleaseVersion(version.Major, version.Minor, version.Build);
    }

    public int CompareTo(ReleaseVersion other)
    {
        var major = Major.CompareTo(other.Major);
        if (major != 0)
        {
            return major;
        }

        var minor = Minor.CompareTo(other.Minor);
        return minor != 0 ? minor : Patch.CompareTo(other.Patch);
    }

    public override string ToString()
    {
        return string.Create(
            CultureInfo.InvariantCulture,
            $"{Major}.{Minor}.{Patch}");
    }

    private static bool TryParsePart(string value, out int part)
    {
        part = 0;
        return value.Length > 0
            && (value.Length == 1 || value[0] != '0')
            && value.All(char.IsAsciiDigit)
            && int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out part);
    }
}
