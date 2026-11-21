param([string]$Cli = 'C:\Program Files\ArtCraft\EffectCraft\effectcraft-cli.exe', [switch]$IkFk, [switch]$PoseMatch, [switch]$Stretch, [switch]$OneBone, [switch]$ThreeBone, [switch]$Bezier, [switch]$BezierFk)
$ErrorActionPreference = 'Stop'
$name = 'Duik for EffectCraft.jsx'
$panel = Join-Path $PSScriptRoot "plug-in\$name"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('opencode\duik-ik-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $temp -Force
$steps = Join-Path $temp 'steps.json'
$project = Join-Path $temp 'IK.ecproj'
$check = Join-Path $temp 'Check.jsx'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Invoke-Cli {
    $result = & $Cli @args
    if ($LASTEXITCODE -ne 0) { throw ($result -join "`n") }
    return ($result -join "`n") | ConvertFrom-Json
}

try {
    if ($PoseMatch -and $Stretch) { throw 'Run -PoseMatch and -Stretch separately.' }
    if (($Bezier -or $BezierFk) -and ($OneBone -or $ThreeBone -or $IkFk -or $PoseMatch -or $Stretch -or ($Bezier -and $BezierFk))) { throw 'Run -Bezier or -BezierFk separately.' }
    if (($OneBone -or $ThreeBone) -and ($IkFk -or $PoseMatch -or $Stretch -or ($OneBone -and $ThreeBone))) { throw 'Run -OneBone or -ThreeBone separately.' }
    if ($PoseMatch -or $Stretch) { $IkFk = $true }
    $widget = if ($BezierFk) { 'buildBezierFk' } elseif ($Bezier) { 'buildBezierIk' } elseif ($ThreeBone) { 'buildThreeIk' } elseif ($OneBone) { 'buildOneIkFk' } elseif ($IkFk) { 'buildIkFk' } else { 'buildIk' }
    $selection = if ($BezierFk) { @('A','B','C','D','Root Ctrl','Start Handle','End Handle','Tip') } elseif ($Bezier) { @('A','B','C','D','Start Handle','End Handle','Tip') } elseif ($ThreeBone) { @('Upper','Middle','Lower','Wrist') } elseif ($OneBone) { @('Upper','Wrist') } else { @('Upper','Lower','Wrist') }
    $setup = @'
var comp = app.project.items.addComp("IK Test", 320, 240, 1, 2, 24);
comp.openInViewer();
var target = comp.layers.addNull(); target.name = "Wrist";
var lower = comp.layers.addSolid([0,1,0], "Lower", 80, 10, 1);
var upper = comp.layers.addSolid([1,0,0], "Upper", 100, 10, 1);
upper.transform.anchorPoint.setValue([0,5]);
lower.transform.anchorPoint.setValue([0,5]);
upper.transform.position.setValue([60,80]);
lower.transform.position.setValue([160,80]);
target.transform.position.setValueAtTime(0,[240,80]);
target.transform.position.setValueAtTime(0.5,[160,140]);
target.transform.position.setValueAtTime(1,[300,80]);
'@
    if ($Bezier -or $BezierFk) {
        $setup = @'
var comp = app.project.items.addComp("Bezier Test",320,240,1,2,24);
comp.openInViewer();
function control(name, from, to) {
    var layer = comp.layers.addNull(); layer.name = name;
    layer.transform.position.setValueAtTime(0,from);
    layer.transform.position.setValueAtTime(1,to);
    layer.transform.position.setValueAtTime(1.5,[60,80]);
}
control("Tip",[180,80],[220,80]);
control("End Handle",[140,80],[220,160]);
control("Start Handle",[100,80],[60,160]);
[["D",140,40],["C",120,20],["B",100,20],["A",60,40]].forEach(function (spec) {
    var layer = comp.layers.addSolid([1,0,0], spec[0], spec[2], 10, 1);
    layer.transform.anchorPoint.setValue([0,5]);
    layer.transform.position.setValue([spec[1],80]);
});
'@
        if ($BezierFk) {
            $setup += "`n" + @'
var root = comp.layers.addNull(); root.name = "Root Ctrl";
root.moveAfter(comp.layer("D"));
root.transform.position.setValueAtTime(0,[60,80]);
root.transform.position.setValueAtTime(1,[90,100]);
root.transform.rotation.setValueAtTime(0,15);
root.transform.rotation.setValueAtTime(1,105);
var tip = comp.layer("Tip");
tip.transform.rotation.setValueAtTime(0,20);
tip.transform.rotation.setValueAtTime(1,20);
tip.transform.rotation.setValueAtTime(1.5,110);
tip.transform.position.setValueAtTime(1.5,[220,80]);
comp.layer("Start Handle").transform.position.setValueAtTime(1.5,[60,160]);
comp.layer("End Handle").transform.position.setValueAtTime(1.5,[220,160]);
'@
        }
    } elseif ($OneBone) {
        $setup += "`n" + @'
lower.remove();
upper.transform.rotation.setValue(15);
target.transform.position.setValueAtTime(0.5,[60,180]);
target.transform.position.setValueAtTime(1,[60,80]);
target.transform.position.setValueAtTime(1.75,[20,80]);
'@
    } elseif ($ThreeBone) {
        $setup += "`n" + @'
var middle = comp.layers.addSolid([0,0,1], "Middle", 40, 10, 1);
middle.moveAfter(upper);
middle.transform.position.setValue([180,80]);
middle.transform.rotation.setValue(90);
lower.transform.position.setValue([180,120]);
target.transform.position.setValueAtTime(0,[210,120]);
target.transform.position.setValueAtTime(0.5,[100,190]);
target.transform.position.setValueAtTime(1,[310,80]);
target.transform.position.setValueAtTime(1.5,[60,90]);
'@
    }
    $commands = @(
        @{command='script.run'; params=@{code=$setup; name='Fixture.jsx'}}
        @{command='script.run'; params=@{code=[IO.File]::ReadAllText($panel); name=$name}}
        @{command='scriptui.click'; params=@{widget=$widget}}
        @{command='scriptui.get'; params=@{}}
        @{command='layer.select'; params=@{layers=@($selection)}}
        @{command='scriptui.click'; params=@{widget=$widget}}
        @{command='scriptui.get'; params=@{}}
    )
    if ($ThreeBone) {
        $commands += @{command='script.run'; params=@{code=@'
var c = app.project.activeItem;
var fx = c.layer("Wrist").property("Effects");
fx.property("Lead Angle").property(1).setValueAtTime(0,0);
fx.property("Lead Angle").property(1).setValueAtTime(0.5,35);
fx.property("Flip Tail Bend").property(1).setValueAtTime(0,false);
fx.property("Flip Tail Bend").property(1).setValueAtTime(0.5,true);
'@}}
    } elseif ($OneBone) {
        $commands += @{command='script.run'; params=@{code=@'
var fx = app.project.activeItem.layer("Wrist").property("Effects");
var mode = fx.property("Use FK").property(1);
mode.setValueAtTime(0,false);
mode.setValueAtTime(1.25,true);
mode.setValueAtTime(1.75,false);
fx.property("FK Rotation").property(1).setValueAtTime(1.25,30);
fx.property("FK Rotation").property(1).setValueAtTime(1.5,60);
'@}}
    } elseif ($PoseMatch) {
        $commands += @(
            @{command='script.run'; params=@{code='app.project.activeItem.time = 0.5;'}}
            @{command='scriptui.click'; params=@{widget='matchIkFk'}}
            @{command='scriptui.get'; params=@{}}
            @{command='script.run'; params=@{code=@'
var c = app.project.activeItem;
var fx = c.layer("Wrist").property("ADBE Effect Parade");
fx.property("FK Shoulder").property(1).setValueAtTime(1,90);
fx.property("FK Elbow").property(1).setValueAtTime(1,90);
c.time = 1.25;
'@}}
            @{command='scriptui.click'; params=@{widget='matchIkFk'}}
            @{command='scriptui.get'; params=@{}}
        )
    } elseif ($Stretch) {
        $commands += @(
            @{command='script.run'; params=@{code=@'
var c = app.project.activeItem;
var stretch = c.layer("Wrist").property("Effects").property("Stretch IK").property(1);
stretch.setValueAtTime(0,false);
stretch.setValueAtTime(0.25,true);
stretch.setValueAtTime(1.25,false);
c.time = 1;
'@}}
            @{command='scriptui.click'; params=@{widget='matchIkFk'}}
            @{command='scriptui.get'; params=@{}}
        )
    } elseif ($IkFk) {
        $animate = @'
var effects = app.project.activeItem.layer("Wrist").property("ADBE Effect Parade");
var mode = effects.property("Use FK").property(1);
mode.setValueAtTime(0, false);
mode.setValueAtTime(1.25, true);
mode.setValueAtTime(1.75, false);
effects.property("FK Shoulder").property(1).setValue(90);
effects.property("FK Elbow").property(1).setValue(-90);
'@
        $commands += @{command='script.run'; params=@{code=$animate; name='Animate Mode.jsx'}}
    }
    [IO.File]::WriteAllText($steps, (ConvertTo-Json -InputObject $commands -Depth 8), $utf8)
    $run = Invoke-Cli run --commands $steps --empty --save-as $project --json
    $details = ConvertTo-Json -InputObject $run -Depth 20 -Compress
    $badSelection = if ($BezierFk) { 'above four control nulls.' } elseif ($Bezier) { 'above three control nulls.' } elseif ($ThreeBone) { 'Rig not built: Select three limbs and a target null' } elseif ($OneBone) { 'Rig not built: Select one limb and its target null.' } else { 'Rig not built: Select upper limb, lower limb, and target null.' }
    if (!$details.Contains($badSelection)) { throw $details }
    $ready = if ($BezierFk) { 'Bezier FK ready.' } elseif ($Bezier) { 'Bezier IK ready.' } elseif ($ThreeBone) { 'Three-bone IK ready.' } elseif ($OneBone) { 'One-bone IK/FK ready.' } elseif ($IkFk) { 'IK/FK ready.' } else { 'Rig ready. Animate Position on Wrist.' }
    if (!$details.Contains($ready)) { throw $details }
    if ($PoseMatch -and (!$details.Contains('Pose matched. Switched to FK.') -or !$details.Contains('Pose matched. Switched to IK.'))) { throw $details }
    if ($Stretch -and !$details.Contains('Move the target within rest reach before matching to FK.')) { throw $details }

    $checkCode = @'
var comp = app.project.item(1);
var u = comp.layer("Upper"), l = comp.layer("Lower"), wrist = comp.layer("Wrist");
function near(a,b,label) { if (!isFinite(a) || Math.abs(a-b) > 0.02) throw new Error(label + ": " + a + " != " + b); }
function verify(t, x, y) {
    var a = u.transform.position.valueAtTime(t,false);
    var b = l.transform.position.valueAtTime(t,false);
    var ur = u.transform.rotation.valueAtTime(t,false)*Math.PI/180;
    var lr = l.transform.rotation.valueAtTime(t,false)*Math.PI/180;
    var us = u.transform.scale.valueAtTime(t,false), ls = l.transform.scale.valueAtTime(t,false);
    near(a[0]+us[0]*Math.cos(ur),b[0],"elbow x");
    near(a[1]+us[0]*Math.sin(ur),b[1],"elbow y");
    near(b[0]+0.8*ls[0]*Math.cos(lr),x,"tip x");
    near(b[1]+0.8*ls[0]*Math.sin(lr),y,"tip y");
    if (u.transform.rotation.expressionError || l.transform.position.expressionError || l.transform.rotation.expressionError) throw new Error("Expression error");
}
verify(0,240,80);
verify(0.5,160,140);
'@
    if ($Bezier -or $BezierFk) {
        $checkCode = @'
var c = app.project.item(1), lengths = [40,20,20,40];
var layers = ["A","B","C","D"].map(function (name) { return c.layer(name); });
function near(a,b,label) { if (!isFinite(a) || Math.abs(a-b)>0.03) throw new Error(label + ": " + a + " != " + b); }
function verify(time, tx, ty) {
    var points = layers.map(function (l) { return l.transform.position.valueAtTime(time,false); });
    points.push([tx,ty]);
    layers.forEach(function (l,i) {
        var t = l.transform, r = t.rotation.valueAtTime(time,false)*Math.PI/180;
        var scale = t.scale.valueAtTime(time,false), len = lengths[i]*scale[0]/100;
        if (!t.rotation.expression || t.rotation.expressionError || t.scale.expressionError || t.position.expressionError) throw new Error("Curve expression failed");
        near(points[i][0]+len*Math.cos(r),points[i+1][0],"joint x");
        near(points[i][1]+len*Math.sin(r),points[i+1][1],"joint y");
        near(scale[0],scale[1],"uniform scale");
    });
    return points;
}
var straight = verify(0,180,80);
near(straight[1][0],100,"rest spacing");
'@
        if ($BezierFk) {
            $checkCode += "`n" + @'
var turned = verify(1,90,260);
near(turned[0][0],90,"translated root x"); near(turned[0][1],100,"translated root y");
near(turned[2][0],30,"rotated curve midpoint x"); near(turned[2][1],180,"rotated curve midpoint y");
var bent = verify(1.5,90,260);
if (Math.abs(bent[3][0]-turned[3][0]) < 5) throw new Error("Tip rotation did not reshape the curve");
"PASS: reopened Bezier FK follows root translation and rotation; tip rotation reshapes the chain without moving its endpoint.";
'@
        } else {
            $checkCode += "`n" + @'
var curved = verify(1,220,80);
near(curved[2][0],140,"curve midpoint x"); near(curved[2][1],140,"curve midpoint y");
if (curved[1][1] <= 80 || curved[3][1] <= 80) throw new Error("Intermediate joints ignored the handles");
verify(1.5,60,80);
"PASS: reopened Bezier rig follows animated handles and tip, joins segments, and tolerates curve collapse.";
'@
        }
    } elseif ($ThreeBone) {
        $checkCode = @'
var c = app.project.item(1), lengths = [120,40,30];
var limbs = [c.layer("Upper"),c.layer("Middle"),c.layer("Lower")];
function near(a,b,label) { if (!isFinite(a) || Math.abs(a-b)>0.02) throw new Error(label + ": " + a + " != " + b); }
function verify(t, x, y) {
    var points = limbs.map(function (l) { return l.transform.position.valueAtTime(t,false); });
    points.push([x,y]);
    limbs.forEach(function (l,i) {
        var r = l.transform.rotation, angle = r.valueAtTime(t,false)*Math.PI/180;
        if (!r.expression || r.expressionError) throw new Error("Three-bone expression missing or invalid");
        near(points[i][0]+lengths[i]*Math.cos(angle),points[i+1][0],"joint x at " + t);
        near(points[i][1]+lengths[i]*Math.sin(angle),points[i+1][1],"joint y at " + t);
    });
    return points;
}
var rest = verify(0,210,120);
near(rest[1][0],180,"rest first joint x"); near(rest[1][1],80,"rest first joint y");
near(rest[2][0],180,"rest second joint x"); near(rest[2][1],120,"rest second joint y");
var b = verify(0.5,100,190);
if ((100-b[1][0])*(b[2][1]-b[1][1])-(190-b[1][1])*(b[2][0]-b[1][0]) >= -1) throw new Error("Tail bend did not flip");
near(limbs[0].transform.rotation.valueAtTime(0.5,false), (Math.atan2(110,40)-Math.atan2(40,150))*180/Math.PI+35,"lead angle");
verify(1,250,80);
verify(1.5,60,130);
"PASS: saved three-bone IK preserves rest pose and lengths, honors bend control, and clamps near and far reach.";
'@
    } elseif ($OneBone) {
        $checkCode = @'
var p = app.project.item(1).layer("Upper").transform.rotation;
function check(t, expected) {
    var value = p.valueAtTime(t,false);
    var delta = ((value-expected)%360+540)%360-180;
    if (!isFinite(value) || Math.abs(delta)>0.02) throw new Error("Rotation at " + t + ": " + value + " != " + expected);
}
if (!p.expression || p.expressionError) throw new Error("One-bone expression missing or invalid");
check(0,15);
check(0.5,105);
check(1,15);
check(1.25,45);
check(1.5,75);
check(1.75,195);
"PASS: saved one-bone rig preserves rest aim offset, follows target, handles coincident pivots, and switches through animated FK.";
'@
    } elseif ($PoseMatch) {
        $checkCode += "`n" + @'
var fx = wrist.property("ADBE Effect Parade"), mode = fx.property("Use FK").property(1);
if (mode.valueAtTime(0.5-1/24,false) || !mode.valueAtTime(0.5,false) || mode.valueAtTime(1.25,false)) throw new Error("Mode switch keys wrong");
var firstJoint = l.transform.position.valueAtTime(0.5,false);
if (100*(firstJoint[1]-80)-60*(firstJoint[0]-60) <= 0) throw new Error("IK to FK changed bend side");
verify(1,-20,180);
verify(1.25,-20,180);
var joint = l.transform.position.valueAtTime(1.25,false);
near(joint[0],60,"matched elbow x");
near(joint[1],180,"matched elbow y");
if (!fx.property("Flip IK Bend").property(1).valueAtTime(1.25,false)) throw new Error("Opposite bend not matched");
"PASS: both switches preserve pose, including reverse bend, after reopening.";
'@
    } elseif ($Stretch) {
        $checkCode += "`n" + @'
verify(1,300,80);
verify(1.25,240,80);
near(u.transform.scale.valueAtTime(0.5,false)[0],100,"in-reach scale");
near(u.transform.scale.valueAtTime(1,false)[0],400/3,"stretch scale");
near(l.transform.scale.valueAtTime(1,false)[1],400/3,"uniform stretch scale");
if (wrist.property("Effects").property("Use FK").property(1).numKeys) throw new Error("Rejected match created mode keys");
"PASS: saved rig tracks beyond reach with stretch on and clamps with stretch off.";
'@
    } elseif ($IkFk) {
        $checkCode += "`n" + @'
verify(1,240,80);
verify(1.25,140,180);
verify(1.5,140,180);
verify(1.75,240,80);
"PASS: saved two-bone rig switches from IK to joint-driven FK and back.";
'@
    } else {
        $checkCode += "`n" + 'verify(1,240,80); "PASS: saved rig follows animated target and clamps out-of-reach poses.";'
    }
    [IO.File]::WriteAllText($check, $checkCode, $utf8)
    (Invoke-Cli script $check $project --json).result
} finally {
    Remove-Item -LiteralPath $steps,$project,$check -ErrorAction SilentlyContinue
    if (!(Get-ChildItem -LiteralPath $temp -Force)) { Remove-Item -LiteralPath $temp }
}
