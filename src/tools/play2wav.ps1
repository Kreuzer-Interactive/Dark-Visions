# play2wav.ps1 -- render QBasic PLAY macro strings to a mono 16-bit WAV
# (square wave, PC-speaker style) so music edits can be auditioned without DOSBox.
# PLAY state (octave/length/tempo/articulation) persists across strings, like QB.
# Usage: dot-source or run; edit the song tables at the bottom, or call:
#   Render-PlaySong -Lines $arrayOfPlayStrings -OutFile out.wav

$cs = @'
using System;
using System.Collections.Generic;
using System.IO;

public static class Play2Wav
{
    const int SR = 22050;
    const short AMP = 7000;

    static int ReadNum(string s, ref int i, int def)
    {
        int start = i;
        int v = 0;
        while (i < s.Length && s[i] >= '0' && s[i] <= '9') { v = v * 10 + (s[i] - '0'); i++; }
        return (i > start) ? v : def;
    }

    static double DotMul(string s, ref int i)
    {
        double mul = 1.0, add = 0.5;
        while (i < s.Length && s[i] == '.') { mul += add; add /= 2.0; i++; }
        return mul;
    }

    static void Emit(List<short> samples, double freq, double dur, double gate)
    {
        int total = (int)Math.Round(dur * SR);
        int on = (freq > 0) ? (int)(total * gate) : 0;
        for (int n = 0; n < total; n++)
        {
            short v = 0;
            if (n < on)
            {
                double phase = n * freq / SR;
                v = (((int)(phase * 2.0)) % 2 == 0) ? AMP : (short)(-AMP);
            }
            samples.Add(v);
        }
    }

    // Renders the strings and returns duration in seconds. Unknown characters
    // are reported to stderr so typos in a song do not fail silently.
    public static double Render(string[] lines, string outPath)
    {
        var samples = new List<short>();
        int octave = 4, len = 4;
        double tempo = 120.0, gate = 7.0 / 8.0;

        foreach (string raw in lines)
        {
            string s = raw.Replace(" ", "").ToUpperInvariant();
            int i = 0;
            while (i < s.Length)
            {
                char c = s[i];
                if (c == '<') { if (octave > 0) octave--; i++; continue; }
                if (c == '>') { if (octave < 6) octave++; i++; continue; }
                if (c == 'O') { i++; octave = ReadNum(s, ref i, octave); continue; }
                if (c == 'L') { i++; len = ReadNum(s, ref i, len); continue; }
                if (c == 'T') { i++; tempo = ReadNum(s, ref i, (int)tempo); continue; }
                if (c == 'M')
                {
                    i++;
                    if (i < s.Length)
                    {
                        char m = s[i]; i++;
                        if (m == 'N') gate = 7.0 / 8.0;
                        else if (m == 'L') gate = 1.0;
                        else if (m == 'S') gate = 3.0 / 4.0;
                        // MB/MF (background/foreground) do not affect rendering
                    }
                    continue;
                }
                if (c == 'P')
                {
                    i++;
                    int n = ReadNum(s, ref i, len);
                    if (n < 1) n = len;
                    double d = (240.0 / tempo) / n * DotMul(s, ref i);
                    Emit(samples, 0, d, 1.0);
                    continue;
                }
                if (c >= 'A' && c <= 'G')
                {
                    int semi;
                    switch (c)
                    {
                        case 'C': semi = 0; break;
                        case 'D': semi = 2; break;
                        case 'E': semi = 4; break;
                        case 'F': semi = 5; break;
                        case 'G': semi = 7; break;
                        case 'A': semi = 9; break;
                        default: semi = 11; break; // B
                    }
                    i++;
                    if (i < s.Length && (s[i] == '+' || s[i] == '#')) { semi++; i++; }
                    else if (i < s.Length && s[i] == '-') { semi--; i++; }
                    int n = ReadNum(s, ref i, len);
                    if (n < 1) n = len;
                    double d = (240.0 / tempo) / n * DotMul(s, ref i);
                    int midi = 12 * octave + semi + 24; // QB O3 C = middle C (MIDI 60)
                    double freq = 440.0 * Math.Pow(2.0, (midi - 69) / 12.0);
                    Emit(samples, freq, d, gate);
                    continue;
                }
                Console.Error.WriteLine("play2wav: unknown char '" + c + "' at " + i + " in: " + raw);
                i++;
            }
        }

        using (var fs = new FileStream(outPath, FileMode.Create))
        using (var w = new BinaryWriter(fs))
        {
            int dataLen = samples.Count * 2;
            w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            w.Write(36 + dataLen);
            w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));
            w.Write(16); w.Write((short)1); w.Write((short)1);
            w.Write(SR); w.Write(SR * 2); w.Write((short)2); w.Write((short)16);
            w.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            w.Write(dataLen);
            foreach (short v in samples) w.Write(v);
        }
        return (double)samples.Count / SR;
    }
}
'@
Add-Type -TypeDefinition $cs

function Render-PlaySong([string[]]$Lines, [string]$OutFile) {
    $sec = [Play2Wav]::Render($Lines, $OutFile)
    "{0}  ({1:n1}s)" -f $OutFile, $sec
}
