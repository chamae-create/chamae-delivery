param(
  [Parameter(Mandatory=$true)][string]$Serial,
  [string[]]$Scenes=@('home','promotions','popular','categories-preview','catalog','cart-state','search','empty','error','large-text','quote-error','no-address')
)
# Requires the debug-only tool/visual_home/main.dart harness already running.
# Does not install, clear data, change settings, or contact production services.
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out=Join-Path $root 'docs/home_visual_sprint_2026-10-21'
[void][IO.Directory]::CreateDirectory($out)
$keys=@{'home'=131;'promotions'=132;'popular'=133;'categories-preview'=134;'catalog'=135;'cart-state'=136;'search'=137;'empty'=138;'error'=139;'large-text'=140;'quote-error'=141;'no-address'=142}
foreach($scene in $Scenes){
  if(-not $keys.ContainsKey($scene)){throw "Unknown Home scene: $scene"}
  & $adb -s $Serial shell input keyevent $keys[$scene]
  if($LASTEXITCODE -ne 0){throw 'ADB keyevent failed'}
  Start-Sleep -Seconds 8
  & $adb -s $Serial shell screencap -p /sdcard/chamae_home_sprint.png
  if($LASTEXITCODE -ne 0){throw 'ADB screencap failed'}
  & $adb -s $Serial pull /sdcard/chamae_home_sprint.png (Join-Path $out "$scene.png")
  if($LASTEXITCODE -ne 0){throw 'ADB pull failed'}
  Write-Output "$scene captured; inspect PNG before approval."
}
& $adb -s $Serial shell rm /sdcard/chamae_home_sprint.png