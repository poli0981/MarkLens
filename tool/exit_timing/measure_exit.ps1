# Times the close of a running MarkLens: how long until the window is gone,
# and how long until the process is (`docs/12_TESTING.md`, "Exit timing").
#
# Posts WM_CLOSE to the main window, which is what the title-bar button,
# Alt+F4 and File -> Exit all reduce to after DefWindowProc, so it exercises
# the real shutdown path rather than a Stop-Process kill.
#
#   .\tool\exit_timing\measure_exit.ps1
#   .\tool\exit_timing\measure_exit.ps1 -OpenArgs 'E:\docs\root' -Runs 5
#   .\tool\exit_timing\measure_exit.ps1 -OpenArgs 'E:\a','E:\b','E:\c','E:\d'
param(
  [string]$Exe = "$PSScriptRoot\..\..\build\windows\x64\runner\Release\marklens.exe",
  [string[]]$OpenArgs = @(),
  [int]$SettleSeconds = 8,
  [int]$Runs = 3,
  [int]$TimeoutMs = 30000
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class U32 {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
}
"@

$results = @()
1..$Runs | ForEach-Object {
  $run = $_
  if ($OpenArgs.Count -gt 0) {
    $p = Start-Process -FilePath $Exe -ArgumentList $OpenArgs -PassThru
  } else {
    $p = Start-Process -FilePath $Exe -PassThru
  }
  Start-Sleep -Seconds $SettleSeconds
  $wait = [Diagnostics.Stopwatch]::StartNew()
  do {
    $p.Refresh()
    Start-Sleep -Milliseconds 100
  } while ($p.MainWindowHandle -eq 0 -and -not $p.HasExited -and $wait.ElapsedMilliseconds -lt 10000)
  if ($p.HasExited -or $p.MainWindowHandle -eq 0) {
    Write-Warning "run $run : no main window (exited=$($p.HasExited))"
    return
  }
  $h = $p.MainWindowHandle

  $sw = [Diagnostics.Stopwatch]::StartNew()
  $hidden = $null
  [U32]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # WM_CLOSE
  while (-not $p.HasExited -and $sw.ElapsedMilliseconds -lt $TimeoutMs) {
    if ($null -eq $hidden -and (-not [U32]::IsWindow($h) -or -not [U32]::IsWindowVisible($h))) {
      $hidden = $sw.ElapsedMilliseconds
    }
    Start-Sleep -Milliseconds 20
    $p.Refresh()
  }
  $exited = $sw.ElapsedMilliseconds
  if (-not $p.HasExited) {
    Write-Warning "run $run : still running after $TimeoutMs ms; killing"
    Stop-Process -Id $p.Id -Force
  }
  if ($null -eq $hidden) { $hidden = $exited }
  $results += [pscustomobject]@{ run = $run; hiddenMs = $hidden; exitedMs = $exited; exited = $p.HasExited }
  "run $run : window hidden at $hidden ms, process exited at $exited ms (exited=$($p.HasExited))"
}
if ($results.Count -gt 0) {
  $m = $results | Measure-Object -Property exitedMs -Average -Minimum -Maximum
  "exit: min {0} ms, avg {1:N0} ms, max {2} ms over {3} runs" -f $m.Minimum, $m.Average, $m.Maximum, $m.Count
}
