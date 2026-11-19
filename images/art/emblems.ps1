# Turns the generated emblems (images/ai/<name>.jpg or .png: a round emblem on black) into the addon's textures:
#   Media/Emblem_<name>.png   128x128, the emblem cut to its circle (the views' headers)
#   Media/Icon_<name>.png     64x64, the same, small (the bar of views)
#   Media/Back_<name>.png     512x512, the same with a soft radial fade (the window's background behind that view)
# and images/ai/icon.* (the addon's icon, on gray) into Icons/Enfocao.png (256) and images/curseforge-icon.png (512).
# The circle is found by looking for the non-black pixels of a small copy of the image; headless Chrome then draws
# it cut to that circle on a transparent page (one temporary page per picture: Chrome mangles file URLs with
# several query parameters). Run from the repo root:
#   powershell -File images/art/emblems.ps1
$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Drawing
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$tmp = Join-Path $env:TEMP "alterao-emblems"
New-Item -ItemType Directory -Force "$repo\Media", $tmp | Out-Null
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# The circle of an emblem: center and radius as fractions of the image's side.
function Find-Circle($path) {
    $src = [System.Drawing.Image]::FromFile($path)
    $n = 200
    $small = New-Object System.Drawing.Bitmap $n, $n
    $g = [System.Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = "HighQualityBilinear"
    $g.DrawImage($src, 0, 0, $n, $n)
    $g.Dispose(); $src.Dispose()
    # the background is whatever color the corner has (black for the emblems, gray for the addon's icon)
    $bg = $small.GetPixel(2, 2)
    $minX, $minY, $maxX, $maxY = $n, $n, -1, -1
    for ($y = 0; $y -lt $n; $y++) {
        for ($x = 0; $x -lt $n; $x++) {
            $p = $small.GetPixel($x, $y)
            if ([Math]::Abs($p.R - $bg.R) + [Math]::Abs($p.G - $bg.G) + [Math]::Abs($p.B - $bg.B) -gt 60) {
                if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    $small.Dispose()
    $cx = ($minX + $maxX + 1) / 2 / $n
    $cy = ($minY + $maxY + 1) / 2 / $n
    $r = [Math]::Max($maxX - $minX + 1, $maxY - $minY + 1) / 2 / $n
    return @($cx, $cy, $r)
}

# One picture cut to its circle, `size` px wide; `fade` adds a soft radial fade to transparent.
function Render($file, $c, $size, $fade, $out, $dest) {
    if (-not $dest) { $dest = "$repo\Media\$out" }
    $r = $c[2] * 0.985 # a hair inside the rim's edge
    $whole = $size / (2 * $r)
    $x = $size / 2 - $c[0] * $whole
    $y = $size / 2 - $c[1] * $whole
    $url = "file:///" + ($file.FullName -replace "\\", "/")
    $mask = ""
    if ($fade) {
        $m = "radial-gradient(circle at 50% 50%, #000 0%, #000 38%, rgba(0,0,0,0.55) 55%, transparent 71%)"
        $mask = "-webkit-mask-image:$m;mask-image:$m;"
    }
    $f = { param($v) $v.ToString("0.###", $inv) }
    $html = "<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>" +
        "<div style=`"width:${size}px;height:${size}px;border-radius:50%;background:url('$url') no-repeat;" +
        "background-size:$(& $f $whole)px $(& $f $whole)px;background-position:$(& $f $x)px $(& $f $y)px;$mask`"></div></body></html>"
    $page = Join-Path $tmp "$out.html"
    Set-Content -Path $page -Value $html -Encoding UTF8
    & $chrome --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --default-background-color=00000000 `
        "--window-size=$size,$size" "--screenshot=$dest" ("file:///" + ($page -replace "\\", "/")) 2>$null | Out-Null
}

foreach ($file in Get-ChildItem "$repo\images\ai" -File | Where-Object { $_.Extension -in ".jpg", ".jpeg", ".png" }) {
    $name = $file.BaseName
    $c = Find-Circle $file.FullName
    if ($name -eq "icon") {
        # the addon's own icon: the game (addon list, minimap button, About, window title) and CurseForge, and the
        # stand-in picture of the views that have none of their own yet ("main")
        Render $file $c 256 $false "icon256" "$repo\Icons\Enfocao.png"
        Render $file $c 512 $false "icon512" "$repo\images\curseforge-icon.png"
        Render $file $c 128 $false "Emblem_main.png"
        Render $file $c 64 $false "Icon_main.png"
        Render $file $c 512 $true "Back_main.png"
    } else {
        Render $file $c 128 $false "Emblem_$name.png"
        Render $file $c 64 $false "Icon_$name.png"
        Render $file $c 512 $true "Back_$name.png"
    }
    "{0}: center {1:N3},{2:N3} radius {3:N3}" -f $name, $c[0], $c[1], $c[2]
}
Remove-Item -Recurse -Force $tmp
