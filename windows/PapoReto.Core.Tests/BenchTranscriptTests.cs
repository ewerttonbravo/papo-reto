namespace PapoReto.Core.Tests;

public class BenchTranscriptTests
{
    // As the Swift bench prints it (Sources/papo-reto-bench/main.swift).
    const string MacOutput = """
        load 2.95 s · footprint 451 MB · resident 470 MB
        luciana.wav · audio 9.4 s · 0.81 s · 0.86 s per 10 s
          Bom dia, pessoal.
        real-01.wav · audio 12.0 s · 1.01 s · 0.84 s per 10 s
          Custa R$ 99,99.
        after transcribing: footprint 812.3 MB · peak 900 MB · resident 820 MB
        within budget
        """;

    [Fact]
    public void ParseReadsTheTextUnderEachFileLine()
    {
        var texts = BenchTranscript.Parse(MacOutput);
        Assert.Equal(new Dictionary<string, string>
        {
            ["luciana.wav"] = "Bom dia, pessoal.",
            ["real-01.wav"] = "Custa R$ 99,99.",
        }, texts);
    }
}
