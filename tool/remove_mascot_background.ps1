param(
    [string]$Source = 'assets/brand/mascot.png',
    [string]$Destination = 'assets/brand/mascot_cutout.png'
)

Add-Type -AssemblyName System.Drawing
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$original = [System.Drawing.Bitmap]::new($sourcePath)
$cutout = [System.Drawing.Bitmap]::new(
    $original.Width,
    $original.Height,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
try {
    $graphics = [System.Drawing.Graphics]::FromImage($cutout)
    try { $graphics.DrawImage($original, 0, 0, $original.Width, $original.Height) }
    finally { $graphics.Dispose() }

    for ($y = 0; $y -lt $cutout.Height; $y++) {
        for ($x = 0; $x -lt $cutout.Width; $x++) {
            $pixel = $cutout.GetPixel($x, $y)
            $red = [int]$pixel.R
            $green = [int]$pixel.G
            $blue = [int]$pixel.B
            # The source backdrop is near-neutral off-white; the lamb's warm
            # cream pigment has a noticeably lower blue channel.
            if ($red -ge 246 -and $green -ge 246 -and $blue -ge 244 -and
                [Math]::Abs($red - $green) -le 6 -and
                [Math]::Abs($green - $blue) -le 9) {
                $cutout.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $red, $green, $blue))
            }
        }
    }
    $cutout.Save($destinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $cutout.Dispose()
    $original.Dispose()
}
