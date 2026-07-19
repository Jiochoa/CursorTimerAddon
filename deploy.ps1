# Copies the addon into the local WoW install for in-game testing.
# After running, type /reload in-game to pick up the changes.
$source = Join-Path $PSScriptRoot "CursorTimer"
$dest = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\CursorTimer"

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$source\*" $dest -Force
Write-Host "Deployed CursorTimer to $dest"
