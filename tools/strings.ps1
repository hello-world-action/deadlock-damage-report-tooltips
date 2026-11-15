# Dump printable ASCII strings (min length 5) from a binary to a text file.
#   .\tools\strings.ps1 -In path\to\client.dll -Out tools\client_strings.txt
param([string]$In, [string]$Out, [int]$Min = 5)

Add-Type -TypeDefinition @'
using System.IO;
using System.Text;
public static class StringsDump {
    public static int Run(string input, string output, int min) {
        byte[] d = File.ReadAllBytes(input);
        int count = 0, start = -1;
        using (var w = new StreamWriter(output, false, new UTF8Encoding(false))) {
            for (int i = 0; i <= d.Length; i++) {
                bool printable = i < d.Length && d[i] >= 0x20 && d[i] < 0x7f;
                if (printable) { if (start < 0) start = i; }
                else if (start >= 0) {
                    if (i - start >= min) { w.WriteLine(Encoding.ASCII.GetString(d, start, i - start)); count++; }
                    start = -1;
                }
            }
        }
        return count;
    }
}
'@
[StringsDump]::Run($In, $Out, $Min)
