param([string[]]$Scenes)
$ErrorActionPreference='Continue'
$adb='C:\Users\DELL\AppData\Local\Android\sdk\platform-tools\adb.exe'
$out=Join-Path (Get-Location) 'docs\visual_homologation_real_device_2026-10-20'
foreach($scene in $Scenes){
 & $adb shell am force-stop br.com.loumak.chamae | Out-Null
 & $adb shell am start -n br.com.loumak.chamae/.MainActivity --es route "/$scene" | Out-Null
 Start-Sleep -Seconds 8
 & $adb shell screencap -p /sdcard/chamae_visual_local.png
 $target=Join-Path $out "local_$scene.png"
 & $adb pull /sdcard/chamae_visual_local.png $target 2>$null | Out-Null
 $attempt=0
 while((Get-Item -LiteralPath $target).Length -lt 20000 -and $attempt -lt 3){
   $attempt++
   Start-Sleep -Seconds 6
   & $adb shell screencap -p /sdcard/chamae_visual_local.png
   & $adb pull /sdcard/chamae_visual_local.png $target 2>$null | Out-Null
 }
 & $adb shell rm /sdcard/chamae_visual_local.png
 Write-Output "$scene : $((Get-Item -LiteralPath $target).Length) bytes"
}