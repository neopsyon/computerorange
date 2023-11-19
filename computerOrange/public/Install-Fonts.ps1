function Install-Font {
    param (
        [Parameter(Mandatory)]
        [string]$FontFileDirectory
    )
    process {
        $ErrorActionPreference = 'Stop'
        $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
        foreach ($file in (Get-ChildItem -Path $FontFileDirectory -Recurse)) {
            $fontFileName = $file.Name
            if ($fontFileName -like "*.ttf" -or $fontFileName -like "*.otf") {
                if (-not (Test-Path "C:\Windows\fonts\$fontFileName")) {
                    $fonts.CopyHere($file.fullname)
                    Copy-Item $file.fullname -Destination 'C:\Windows\fonts\'
                }
            }
            
        }
    }
}