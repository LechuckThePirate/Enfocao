# Changes the hue of the purple parts of a picture (Enfocao's icon was generated purple, Emboscao's color), leaving
# every other color alone (gold, skin, parchment, the gray background).
#   powershell -File images/art/recolor.ps1 -In images/ai/icon_purple.jpg -Out images/ai/icon.png -Hue 330
# -Hue is the new hue in degrees (330 pink, 25 orange...); purple is taken as the hues 235-320.
param([string]$In, [string]$Out, [double]$Hue)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Recolor {
    static void ToHsv(double r, double g, double b, out double h, out double s, out double v) {
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b)), d = max - min;
        v = max; s = max == 0 ? 0 : d / max; h = 0;
        if (d == 0) return;
        if (max == r) h = 60 * (((g - b) / d) % 6);
        else if (max == g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
        if (h < 0) h += 360;
    }
    static void ToRgb(double h, double s, double v, out double r, out double g, out double b) {
        double c = v * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c;
        double r1 = 0, g1 = 0, b1 = 0;
        if (h < 60) { r1 = c; g1 = x; } else if (h < 120) { r1 = x; g1 = c; } else if (h < 180) { g1 = c; b1 = x; }
        else if (h < 240) { g1 = x; b1 = c; } else if (h < 300) { r1 = x; b1 = c; } else { r1 = c; b1 = x; }
        r = r1 + m; g = g1 + m; b = b1 + m;
    }
    public static void Run(string input, string output, double target) {
        using (var src = new Bitmap(input))
        using (var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb)) {
            using (var gr = Graphics.FromImage(bmp)) gr.DrawImage(src, 0, 0, src.Width, src.Height);
            var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
            var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var px = new byte[data.Stride * bmp.Height];
            Marshal.Copy(data.Scan0, px, 0, px.Length);
            for (int i = 0; i < px.Length; i += 4) {
                double b = px[i] / 255.0, g = px[i + 1] / 255.0, r = px[i + 2] / 255.0, h, s, v;
                ToHsv(r, g, b, out h, out s, out v);
                if (s < 0.12 || h < 235 || h > 320) continue;
                // purple's middle (about 275) goes to the target; the shades around it keep their distance
                double nh = (target + (h - 275) + 360) % 360;
                ToRgb(nh, s, v, out r, out g, out b);
                px[i] = (byte)Math.Round(b * 255); px[i + 1] = (byte)Math.Round(g * 255); px[i + 2] = (byte)Math.Round(r * 255);
            }
            Marshal.Copy(px, 0, data.Scan0, px.Length);
            bmp.UnlockBits(data);
            bmp.Save(output, ImageFormat.Png);
        }
    }
}
"@
[Recolor]::Run((Resolve-Path $In).Path, [System.IO.Path]::GetFullPath($Out), $Hue)
