using System.Net.WebSockets;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using MihomoMeter.Windows.Core.Infrastructure.Mihomo;

namespace MihomoMeter.Windows.Tests;

[TestClass]
public sealed class ConnectionMessageAssemblerTests
{
    [TestMethod]
    public void DecodesCompleteTextMessage()
    {
        var payload = FixtureLoader.Load("connections-next");
        using var assembler = new ConnectionMessageAssembler();

        var completed = assembler.Append(WebSocketMessageType.Text, payload, true);
        var snapshot = assembler.Decode();

        Assert.IsTrue(completed);
        Assert.AreEqual((ulong)1_400, snapshot.UploadTotal);
        Assert.AreEqual((ulong)2_900, snapshot.DownloadTotal);
    }

    [TestMethod]
    public void DecodesFragmentedBinaryMessage()
    {
        var payload = FixtureLoader.Load("connections-next");
        var splitIndex = payload.Length / 2;
        using var assembler = new ConnectionMessageAssembler();

        var firstCompleted = assembler.Append(
            WebSocketMessageType.Binary,
            payload.AsSpan(0, splitIndex),
            false);
        var secondCompleted = assembler.Append(
            WebSocketMessageType.Binary,
            payload.AsSpan(splitIndex),
            true);
        var snapshot = assembler.Decode();

        Assert.IsFalse(firstCompleted);
        Assert.IsTrue(secondCompleted);
        Assert.AreEqual(2, snapshot.Connections.Count);
    }
}
