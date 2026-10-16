# car3dturn.ps1 -- print the intro car's recorded turn (src\C3DTURN.DAT, written by the
# game's turn editor: tools\game_edit.conf) as degrees of extra heading per road step.
# Left-arrow presses are negative (the car turns left), right-arrow presses positive.
#
#   powershell -ExecutionPolicy Bypass -File src\tools\car3dturn.ps1
#   ... -Every 10        one line per 10 steps (default 10)
param([int]$Every = 10)
$f = Join-Path (Resolve-Path "$PSScriptRoot\..").Path 'C3DTURN.DAT'
if (-not (Test-Path $f)) { "no recording: $f (drive the car with tools\game_edit.conf first)"; exit 1 }
$b = [IO.File]::ReadAllBytes($f)
if ($b.Length -lt 6 -or [Text.Encoding]::ASCII.GetString($b, 0, 4) -ne 'C3DT') { "not a recording: $f"; exit 1 }
$n = [BitConverter]::ToInt16($b, 4)
"$n steps recorded (step 200 = the bend's start)"
$last = $null
for ($d = 0; $d -lt $n; $d++) {
    $q = [BitConverter]::ToInt16($b, 6 + $d * 2)
    if (($d % $Every) -eq 0 -or $d -eq $n - 1) {
        $deg = $q / 4.0
        $bar = ''
        if ($q -lt 0) { $bar = ('<' * [Math]::Min(60, [int](-$q / 4))) } elseif ($q -gt 0) { $bar = ('>' * [Math]::Min(60, [int]($q / 4))) }
        "{0,4}: {1,6:0.0} deg  {2}" -f $d, $deg, $bar
    }
}
