using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MihomoMeter.Windows.Core.Infrastructure.Mihomo;

public sealed class TolerantDateTimeOffsetJsonConverter : JsonConverter<DateTimeOffset?>
{
    public override DateTimeOffset? Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.String
            && DateTimeOffset.TryParse(
                reader.GetString(),
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var value))
        {
            return value;
        }

        if (reader.TokenType is JsonTokenType.StartArray or JsonTokenType.StartObject)
        {
            using var ignored = JsonDocument.ParseValue(ref reader);
        }

        return null;
    }

    public override void Write(
        Utf8JsonWriter writer,
        DateTimeOffset? value,
        JsonSerializerOptions options)
    {
        throw new NotSupportedException("连接开始时间只允许从 Mihomo 响应解码。");
    }
}
