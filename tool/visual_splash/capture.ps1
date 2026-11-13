param([Parameter(Mandatory=$true)][string]$Serial)
# Use only with tool/visual_splash/main.dart already installed and unlocked.
# No installation, app-data clearing, production services or device settings here.
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out=Join-Path $root 'docs/splash_final_correction_2026-10-21'
$scratch=Join-Path $root '.dart_tool/splash_official_2026_10_21'
[void][IO.Directory]::CreateDirectory($out)
function Capture([string]$Name) {
 & $adb -s $Serial shell screencap -p /sdcard/chamae_splash.png
 if($LASTEXITCODE -ne 0){throw 'Screenshot failed'}
 & $adb -s $Serial pull /sdcard/chamae_splash.png (Join-Path $out ($Name+'.png'))
 if($LASTEXITCODE -ne 0){throw 'Pull failed'}
 Write-Output "Captured $Name; inspect before approval."
}
foreach($run in @('01','02')) {
 & $adb -s $Serial shell am force-stop br.com.loumak.chamae
 $start=& $adb -s $Serial shell am start -W -n br.com.loumak.chamae/.MainActivity
 [IO.File]::WriteAllLines((Join-Path $out "cold_${run}_start.txt"),[string[]]$start)
 Start-Sleep -Seconds 4
 Capture "cold_${run}_metrics"
}
& $adb -s $Serial shell input keyevent KEYCODE_HOME
Start-Sleep -Seconds 1
$resume=& $adb -s $Serial shell am start -W -n br.com.loumak.chamae/.MainActivity
[IO.File]::WriteAllLines((Join-Path $out 'reopen_start.txt'),[string[]]$resume)
Start-Sleep -Seconds 1
Capture 'reopen_no_replay'
foreach($scene in @(@{Key=132;Name='official_splash'},@{Key=133;Name='error_retry'},@{Key=135;Name='reduced_motion'})) {
 & $adb -s $Serial shell input keyevent $scene.Key
 Start-Sleep -Seconds 4
 Capture $scene.Name
}
& $adb -s $Serial shell am force-stop br.com.loumak.chamae
# Recording begins just after launch request, before the Flutter sequence.
$launch=Start-Process -FilePath $adb -ArgumentList @('-s',$Serial,'shell','am','start','-W','-n','br.com.loumak.chamae/.MainActivity') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $out 'sequence_start.txt') -RedirectStandardError (Join-Path $scratch 'sequence-launch-stderr.txt')
Start-Sleep -Milliseconds 100
$record=Start-Process -FilePath $adb -ArgumentList @('-s',$Serial,'shell','screenrecord','--bit-rate','2500000','--time-limit','8','/sdcard/chamae_splash_sequence.mp4') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $scratch 'record-stdout.txt') -RedirectStandardError (Join-Path $scratch 'record-stderr.txt')
if(-not $record.WaitForExit(15000)){throw 'Recorder did not finish within its expected duration'}
[void]$launch.WaitForExit(5000)
& $adb -s $Serial pull /sdcard/chamae_splash_sequence.mp4 (Join-Path $out 'cold_sequence.mp4')
if($LASTEXITCODE -ne 0){throw 'Video pull failed'}
& $adb -s $Serial shell rm /sdcard/chamae_splash.png /sdcard/chamae_splash_sequence.mp4
Write-Output 'Capture sequence completed; PNG/video inspection required.'
