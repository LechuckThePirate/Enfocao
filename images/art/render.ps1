# Renders the drawn backgrounds (images/art/backdrop.html) to Media/*.png (the emblems come from images/ai, see emblems.ps1) with headless Chrome. Run from the repo root:
#   powershell -File images/art/render.ps1
$ErrorActionPreference = "Continue"
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$art = "file:///" + ($PSScriptRoot -replace "\\", "/")
New-Item -ItemType Directory -Force "$repo\Media" | Out-Null

function Render($page, $out, $w, $h) {
    & $chrome --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 `
        "--window-size=$w,$h" "--screenshot=$repo\Media\$out" "$art/$page" 2>&1 | Out-Null
}

Render "backdrop.html?b=banner" "Banner.png" 1024 128
Render "backdrop.html?b=window" "Window.png" 512 512
Get-ChildItem "$repo\Media" | Select-Object Name, Length
