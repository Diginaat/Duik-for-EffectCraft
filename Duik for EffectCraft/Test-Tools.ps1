param([string]$Cli = 'C:\Program Files\ArtCraft\EffectCraft\effectcraft-cli.exe', [string]$Only = '')
# Headless checks for the Animation, Automation, constraint, layer, and template tools.
# Each case builds a fixture comp, drives panel widgets, then verifies the result after saving and reopening.
$ErrorActionPreference = 'Stop'
$name = 'Duik for EffectCraft.jsx'
$panel = Join-Path $PSScriptRoot "plug-in\$name"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('effectcraft-duik-tools-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $temp -Force
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Invoke-Cli {
    $result = & $Cli @args
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return ($result -join "`n") | ConvertFrom-Json
}

# Shared helpers for check scripts.
$prelude = @'
function near(actual, expected, label, tolerance) {
    tolerance = tolerance || 0.02;
    var a = [].concat(actual), e = [].concat(expected);
    for (var i = 0; i < e.length; i++) {
        if (!(Math.abs(a[i]-e[i]) <= tolerance)) throw new Error(label + ": " + actual + " != " + expected);
    }
}
function comp(name) {
    for (var i = 1; i <= app.project.numItems; i++) if (app.project.item(i).name === name) return app.project.item(i);
    throw new Error("Missing comp " + name);
}
'@

$cases = @(. (Join-Path $PSScriptRoot 'Test-Tools.Cases.ps1'))
if ($Only) { $cases = @($cases | Where-Object { $_.Name -like $Only }) }
if (!$cases.Count) { throw "No cases match $Only" }

$commands = @(@{command='script.run'; params=@{code=[IO.File]::ReadAllText($panel); name=$name}})
foreach ($case in $cases) {
    $setup = "var c = app.project.items.addComp(" + (ConvertTo-Json $case.Name) + ",320,240,1,4,24); c.openInViewer();`n" + $case.Setup
    $commands += @{command='script.run'; params=@{code=$setup; name="$($case.Name) setup.jsx"}}
    foreach ($step in $case.Steps) {
        if ($step -is [string]) {
            if ($step.StartsWith('select:')) {
                $commands += @{command='layer.select'; params=@{layers=@($step.Substring(7).Split('|'))}}
            } else {
                $commands += @{command='scriptui.click'; params=@{widget=$step}}
                $commands += @{command='scriptui.get'; params=@{}}
            }
        } elseif ($step.Script) {
            $commands += @{command='script.run'; params=@{code=$step.Script; name="$($case.Name) step.jsx"}}
        } else {
            $commands += @{command='scriptui.set'; params=@{widget=$step.Widget; value=$step.Value}}
        }
    }
}
$steps = Join-Path $temp 'steps.json'
$project = Join-Path $temp 'Tools.ecproj'
[IO.File]::WriteAllText($steps, (ConvertTo-Json -InputObject $commands -Depth 8), $utf8)
$run = Invoke-Cli run --commands $steps --empty --save-as $project --json
$details = ConvertTo-Json -InputObject $run -Depth 20 -Compress
$failed = 0
foreach ($case in $cases) {
    foreach ($text in @($case.Expect)) {
        if ($text -and !$details.Contains($text)) { Write-Output "FAIL $($case.Name): status '$text' not shown"; $failed++ }
    }
    $check = Join-Path $temp 'Check.jsx'
    $code = $prelude + "var c = comp(" + (ConvertTo-Json $case.Name) + ");`n" + $case.Check + "`n'ok';"
    [IO.File]::WriteAllText($check, $code, $utf8)
    try {
        $null = Invoke-Cli script $check $project --json
        Write-Output "PASS $($case.Name)"
    } catch {
        Write-Output "FAIL $($case.Name): $($_.Exception.Message)"
        $failed++
    }
}
if ($failed) {
    $log = Join-Path $temp 'run.json'
    [IO.File]::WriteAllText($log, $details, $utf8)
    throw "$failed check(s) failed. Run log: $log"
}
Remove-Item -LiteralPath $temp -Recurse -ErrorAction SilentlyContinue
