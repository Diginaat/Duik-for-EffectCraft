param([string]$App = 'C:\Program Files\ArtCraft\EffectCraft\effectcraft.exe')
$ErrorActionPreference = 'Stop'
$bundle = Join-Path $PSScriptRoot 'plug-in'
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$process = Start-Process -FilePath $App -ArgumentList @('--control', "$port") -PassThru
$client = $null
$writer = $null
$reader = $null
$window = $null

function Request($method, $parameters) {
    $writer.WriteLine((ConvertTo-Json -InputObject @{id=1; method=$method; params=$parameters} -Depth 10 -Compress))
    $reply = $reader.ReadLine() | ConvertFrom-Json
    if (!$reply.ok) { throw $reply.error }
    return $reply.result
}

function Command($id, $parameters = @{}) {
    Request 'engine.execute' @{command=$id; params=$parameters}
}

function Script($code) {
    $result = Command 'script.run' @{code=$code; name='Test Additional Tools.jsx'}
    if (!$result.ok) { throw ($result.error | ConvertTo-Json -Compress) }
    return $result.result
}

function Click($widget) {
    Command 'scriptui.click' @{window=$window; widget=$widget} | Out-Null
}

try {
    for ($i=0; $i -lt 40; $i++) {
        $client = [Net.Sockets.TcpClient]::new()
        try { $client.Connect('127.0.0.1', $port); break }
        catch { $client.Dispose(); $client=$null; Start-Sleep -Milliseconds 250 }
    }
    if (!$client) { throw 'EffectCraft desktop control channel did not open.' }
    $stream = $client.GetStream()
    $stream.ReadTimeout = 20000
    $reader = [IO.StreamReader]::new($stream)
    $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true

    $installed = @(Command 'file.scripts.list')
    $name = 'Duik for EffectCraft.jsx'
    if ($name -notin $installed.name) {
        $result = Command 'effect.plugins.install' @{folder=$bundle}
        if ($result.errors.Count -or $result.panels.Count -ne 1 -or $result.panels[0] -ne $name) { throw ($result | ConvertTo-Json -Depth 6) }
    }
    $opened = Command 'window.scriptPanel' @{name=$name}
    if (!$opened.window -or ($opened.result -and !$opened.result.ok)) { throw ($opened | ConvertTo-Json -Depth 6) }
    $window = $opened.window
    $panel = @(Command 'scriptui.list' | Where-Object { $_.window -eq $window -and $_.kind -eq 'panel' -and $_.script -eq $name })
    if ($panel.Count -ne 1) { throw 'Unified plug-in did not open as a dockable panel.' }
    # Sections switch through a row of drawn icon buttons; the visible page must sit below the toolbar.
    function Layout { $root = (Command 'scriptui.get' @{window=$window}).root; return @{ header=$root.children[0]; pages=$root.children[1] } }
    $layout = Layout
    $bar = $layout.header.children | Where-Object { $_.name -eq 'duikTabs' }
    $expectedTabs = 'tabRigging,tabArmature,tabConstraints,tabAnimation,tabAutomation,tabLayers,tabCamera'
    if (($bar.children.name -join ',') -ne $expectedTabs -or @($bar.children | Where-Object { !$_.draw.Count }).Count) { throw 'Expected seven drawn section icons in the toolbar.' }
    foreach ($index in 0..($bar.children.Count - 1)) {
        Click $bar.children[$index].name
        $layout = Layout
        $visible = @($layout.pages.children | Where-Object { $_.visible })
        $title = ($layout.header.children | Where-Object { $_.name -eq 'sectionTitle' }).text
        if ($visible.Count -ne 1 -or $visible[0] -ne $layout.pages.children[$index] -or $title -ne $bar.children[$index].helpTip) { throw "Icon $index did not switch to its section." }
        $toolbarBottom = $layout.header.bounds[1] + $layout.header.bounds[3]
        if ($visible[0].children[0].bounds[1] -lt $toolbarBottom) { throw "$title content overlaps the toolbar." }
    }
    Script @'
var c = app.project.items.addComp("Tools Test", 320, 240, 1, 4, 24);
c.openInViewer();
var a = c.layers.addSolid([1,0,0], "Art", 50, 50, 1);
a.transform.position.setValue([70,90]);
a.selected = true;
'@ | Out-Null
    Click 'tabLayers'
    foreach ($widget in @('addControls','addZeros','addSolid','addAdjustment')) {
        if ($widget -eq 'addZeros') { Command 'layer.select' @{layers=@('Art')} | Out-Null }
        Click $widget
    }
    Script @'
var c = app.project.activeItem, a = c.layer("Art"), p = c.layer("Zero - Art"), ctrl = c.layer("Ctrl - Art");
if (!ctrl || !ctrl.nullLayer || !p || a.parent !== p) throw new Error("Controller/parent not created");
function same(position, x, y) { return Math.abs(position[0]-x)<0.001 && Math.abs(position[1]-y)<0.001; }
if (!same(ctrl.transform.position.value,70,90) || !same(p.transform.position.value,70,90) || !same(a.transform.position.value,0,0)) throw new Error("Control alignment wrong");
if (!c.layer("Adjustment").adjustmentLayer || c.layer("Solid").width !== c.width) throw new Error("Layer creation wrong");
var r = ctrl.transform.rotation;
r.setValueAtTime(1,0); r.setValueAtTime(2,90);
r.selected = true;
'@ | Out-Null
    Click 'tabAutomation'
    Click 'cycleLoop'
    Script @'
var ctrl = app.project.activeItem.layer("Ctrl - Art"), r = ctrl.transform.rotation;
if (!r.expression || r.expressionError || Math.abs(r.valueAtTime(0.5,false)-45)>0.02 || Math.abs(r.valueAtTime(2.5,false)-45)>0.02) throw new Error("Loop failed: " + r.expressionError + " " + r.valueAtTime(0.5,false) + " " + r.valueAtTime(2.5,false));
r.selected = false;
ctrl.transform.position.selected = true;
'@ | Out-Null
    Click 'wiggle'
    Script @'
var p = app.project.activeItem.layer("Ctrl - Art").transform.position;
if (!p.expression || p.expressionError || String(p.valueAtTime(0.5,false)) === String(p.valueAtTime(1.25,false))) throw new Error("Wiggle failed");
"PASS: Layers and Automation tabs create native layers and zero parents, loop, and wiggle.";
'@
    Script @'
var c = app.project.items.addComp("Armature Test",320,240,1,4,24);
c.openInViewer();
var tip = c.layers.addSolid([1,1,1],"Tip",10,10,1);
var root = c.layers.addSolid([1,1,1],"Root",10,10,1);
tip.transform.position.setValue([130,80]);
root.transform.position.setValue([60,80]);
'@ | Out-Null
    Command 'layer.select' @{layers=@('Root','Tip')} | Out-Null
    Click 'tabArmature'
    Click 'buildFk'
    Script @'
var c=app.project.activeItem, a=c.layer("Root"), b=c.layer("Tip"), root=c.layer("Bone - Root"), tip=c.layer("Bone - Tip");
if (a.parent!==root || b.parent!==tip || tip.parent!==root) throw new Error("FK hierarchy missing");
var extra=c.layers.addSolid([1,1,1],"Extra art",10,10,1);
extra.transform.position.setValue([130,95]);
extra.moveToEnd();
'@ | Out-Null
    Command 'layer.select' @{layers=@('Bone - Tip','Extra art')} | Out-Null
    Click 'bindArt'
    Script @'
var c=app.project.activeItem, root=c.layer("Bone - Root"), tip=c.layer("Bone - Tip"), extra=c.layer("Extra art");
if (extra.parent!==tip) throw new Error("Artwork binding missing");
root.transform.rotation.setValue(90);
var probe=c.layers.addNull(); probe.name="FK Probe";
var p=probe.transform.position;
p.expression='var l=thisComp.layer("Extra art"); l.toComp(l.anchorPoint);';
var v=p.value;
if (p.expressionError || Math.abs(v[0]-45)>0.01 || Math.abs(v[1]-150)>0.01) throw new Error("FK artwork failed: " + v + " " + p.expressionError);
var follower=c.layers.addSolid([1,1,1],"Follower",10,10,1);
var aim=c.layers.addSolid([1,1,1],"Pointer",10,10,1);
var driver=c.layers.addNull(); driver.name="Driver";
driver.transform.position.setValueAtTime(0,[120,60]);
driver.transform.position.setValueAtTime(1,[60,120]);
aim.transform.position.setValue([60,60]);
follower.transform.position.setValue([130,80]);
'@ | Out-Null
    Command 'layer.select' @{layers=@('Driver','Pointer')} | Out-Null
    Click 'aim'
    Command 'layer.select' @{layers=@('Driver','Follower')} | Out-Null
    Click 'follow'
    Script @'
var c=app.project.activeItem, r=c.layer("Pointer").transform.rotation, p=c.layer("Follower").transform.position;
var v=p.valueAtTime(1,false);
if (!r.expression || r.expressionError || Math.abs(r.valueAtTime(1,false)-90)>0.01) throw new Error("Aim failed: " + r.expressionError);
if (!p.expression || p.expressionError || Math.abs(v[0]-70)>0.01 || Math.abs(v[1]-140)>0.01) throw new Error("Position constraint failed: " + p.expressionError + " " + v);
"PASS: Armature tab builds FK, binds artwork, and constrains aim and position.";
'@
    Script @'
var c=app.project.items.addComp("Overlap Test",320,240,1,4,24);
c.openInViewer();
[["End",180],["Mid",120],["Base",60]].forEach(function (s) {
    var a=c.layers.addSolid([1,1,1],s[0],20,10,1);
    a.transform.position.setValue([s[1],80]);
});
'@ | Out-Null
    Command 'layer.select' @{layers=@('Base','Mid','End')} | Out-Null
    Click 'buildOverlapFk'
    Script @'
var c=app.project.activeItem, root=c.layer("Bone - Base"), mid=c.layer("Bone - Mid"), end=c.layer("Bone - End");
var effects=root.property("Effects"), r=root.transform.rotation, m=mid.transform.rotation, e=end.transform.rotation;
if (mid.parent!==root || end.parent!==mid || c.layer("End").parent!==end) throw new Error("Overlap hierarchy missing");
effects.property("Delay Frames").property(1).setValue(6);
r.setValueAtTime(0,0); r.setValueAtTime(1,90);
function near(actual, expected) {
    if (!isFinite(actual) || Math.abs(actual-expected)>0.02) throw new Error("Overlap angle " + actual + " != " + expected + " / " + m.expressionError);
}
function angles(time, middle, tip) {
    var base=r.valueAtTime(time,false), joint=m.valueAtTime(time,false);
    near(base+joint,middle);
    near(base+joint+e.valueAtTime(time,false),tip);
}
angles(0.75,45,22.5);
angles(1.5,90,90);
effects.property("Overlap Amount").property(1).setValue(0);
angles(0.75,67.5,67.5);
"PASS: overlapping FK staggers joint rotation, settles, and bypasses at zero amount.";
'@
    Script @'
var c=app.project.activeItem;
var layer=c.layers.addSolid([1,1,1],"Wheel",100,100,1);
var p=layer.transform.position, r=layer.transform.rotation;
r.setValue(10);
p.setValueAtTime(0,[100,100]);
p.setValueAtTime(1,[100+50*Math.PI,100]);
p.setValueAtTime(2,[100-50*Math.PI,100]);
c.time=0;
'@ | Out-Null
    Command 'layer.select' @{layers=@('Wheel')} | Out-Null
    Click 'tabAutomation'
    Click 'rollWheel'
    Script @'
var p=app.project.activeItem.layer("Wheel").transform.rotation;
[10,190,-170].forEach(function (expected, time) {
    var actual=p.valueAtTime(time,false);
    if (!p.expression || p.expressionError || Math.abs(actual-expected)>0.02) throw new Error("Wheel rotation: " + actual + " != " + expected);
});
"PASS: wheel rolls by travel/radius, preserving its setup rotation and reversing with travel.";
'@
    Script @'
app.project.items.addComp("Template Test",320,240,1,4,24).openInViewer();
'@ | Out-Null
    Click 'tabRigging'
    Click 'buildLimbTemplate'
    Click 'buildLimbTemplate'
    Command 'scriptui.set' @{window=$window; widget='limbTemplate'; value=1} | Out-Null
    Click 'buildLimbTemplate'
    Script @'
var c=app.project.activeItem;
if (c.numLayers!==9) throw new Error("Template creation did not add three layers per rig");
function rig(prefix, names) {
    var layers=names.map(function (name) { return c.layer(prefix+" - "+name); });
    if (layers.some(function (l) { return !l || !l.nullLayer; })) throw new Error("Missing bones or target for " + prefix);
    if (!(layers[0].index<layers[1].index && layers[1].index<layers[2].index)) throw new Error("Template order wrong");
    if (!layers[2].property("Effects").property("Use FK")) throw new Error("Target controls missing");
    return layers;
}
var arm=rig("Arm",["Shoulder","Elbow","Wrist"]);
var second=rig("Arm 2",["Shoulder","Elbow","Wrist"]);
var leg=rig("Leg",["Hip","Knee","Ankle"]);
if (c.selectedLayers.length!==1 || c.selectedLayers[0]!==leg[2]) throw new Error("Target not selected");
var art=c.layers.addSolid([1,0,0],"Leg Artwork",20,10,1);
art.transform.position.setValue(leg[1].transform.position.value);
art.moveToEnd();
'@ | Out-Null
    Click 'tabArmature'
    Command 'layer.select' @{layers=@('Leg - Knee','Leg Artwork')} | Out-Null
    Click 'bindArt'
    Script @'
var c=app.project.activeItem, knee=c.layer("Leg - Knee"), ankle=c.layer("Leg - Ankle"), art=c.layer("Leg Artwork");
var second=c.layer("Arm 2 - Elbow").transform.position.value;
if (art.parent!==knee) throw new Error("Template bone did not bind artwork");
var old=knee.transform.position.value;
ankle.transform.position.setValue([200,190]);
var moved=knee.transform.position.value;
if (knee.transform.position.expressionError || Math.abs(moved[0]-old[0])<1) throw new Error("Template target did not drive its bone");
if (String(second)!==String(c.layer("Arm 2 - Elbow").transform.position.value)) throw new Error("Template rigs interfere");
"PASS: arm and leg templates create independent two-bone rigs and accept artwork binding.";
'@
    Script @'
var c=app.project.activeItem, p=c.layer("Arm - Wrist").transform.position;
p.setValueAtTime(0,p.value); p.setValueAtTime(1,[200,145]);
'@ | Out-Null
    Click 'tabRigging'
    Command 'layer.select' @{layers=@('Arm - Wrist','Leg - Ankle')} | Out-Null
    Click 'buildRigMaster'
    Script @'
var c=app.project.activeItem, master=c.layer("Rig Master"), wrist=c.layer("Arm - Wrist"), knee=c.layer("Leg - Knee");
if (!master || wrist.parent!==master || knee.parent!==master || c.layer("Arm 2 - Wrist").parent) throw new Error("Master hierarchy wrong");
var p=wrist.transform.position;
if (p.numKeys!==2 || p.keyValue(2)[0]!==200 || p.keyValue(2)[1]!==145) throw new Error("Master rewrote existing keyframes");
var probe=c.layers.addNull().transform.position;
probe.expression='var l=thisComp.layer("Arm - Wrist"); l.toComp(l.anchorPoint);';
function near(v,x,y) { if (Math.abs(v[0]-x)>0.01 || Math.abs(v[1]-y)>0.01) throw new Error("Master transform wrong: " + v); }
near(probe.valueAtTime(1,false),200,145);
master.transform.position.setValue([190,130]);
master.transform.rotation.setValue(90);
near(probe.valueAtTime(1,false),165,170);
if (probe.expressionError || knee.transform.position.expressionError) throw new Error("Grouped expression error");
c.time=1;
'@ | Out-Null
    Command 'layer.select' @{layers=@('Arm - Shoulder','Arm - Elbow','Arm - Wrist')} | Out-Null
    Click 'matchIkFk'
    Script @'
var c=app.project.activeItem;
if (!c.layer("Arm - Wrist").property("Effects").property("Use FK").property(1).value) throw new Error("Pose switch failed under master");
"PASS: master moves grouped rigs without rewriting target keys; grouped pose matching works.";
'@
    Script @'
var c=app.project.items.addComp("Parent Constraint Test",320,240,1,4,24); c.openInViewer();
var follower=c.layers.addSolid([1,0,0],"Payload",20,20,1);
var driver=c.layers.addNull(); driver.name="Parent Driver";
follower.transform.position.setValue([140,100]);
follower.transform.rotation.setValueAtTime(0,10); follower.transform.rotation.setValueAtTime(1,20);
driver.transform.position.setValueAtTime(0,[100,100]); driver.transform.position.setValueAtTime(1,[120,110]);
driver.transform.rotation.setValueAtTime(0,15); driver.transform.rotation.setValueAtTime(1,105);
'@ | Out-Null
    Click 'tabArmature'
    Command 'layer.select' @{layers=@('Parent Driver','Payload')} | Out-Null
    Click 'parentWeight'
    Script @'
var f=app.project.activeItem.layer("Payload"), t=f.transform;
var w=f.property("Effects").property("Parent Weight").property(1);
function check(time,x,y,r) {
    var p=t.position.valueAtTime(time,false), actual=t.rotation.valueAtTime(time,false);
    if (t.position.expressionError || t.rotation.expressionError || Math.abs(p[0]-x)>0.02 || Math.abs(p[1]-y)>0.02 || Math.abs(actual-r)>0.02) throw new Error("Wrong weighted pose: " + p + "; " + actual);
}
if (f.parent || t.rotation.numKeys!==2) throw new Error("Constraint changed hierarchy or base keys");
check(0,140,100,10);
check(1,120,150,110);
w.setValueAtTime(1,100); w.setValueAtTime(2,50); w.setValueAtTime(3,0);
check(2,130,125,65);
check(3,140,100,20);
"PASS: animated parent weights blend translation and rotation without replacing keys or hierarchy.";
'@
    Script @'
var c=app.project.items.addComp("Path Constraint Test",320,240,1,4,24); c.openInViewer();
var follower=c.layers.addSolid([1,0,0],"Traveler",20,20,1);
var driver=c.layers.addSolid([0,0,0],"Track",100,100,1);
driver.transform.anchorPoint.setValue([0,0]);
driver.transform.position.setValue([120,60]);
driver.transform.rotation.setValue(90);
driver.transform.scale.setValue([150,100]);
var mask=driver.property("ADBE Mask Parade").addProperty("ADBE Mask Atom");
mask.name="Travel Route"; mask.maskMode=MaskMode.NONE;
var shape=new Shape(); shape.vertices=[[0,0],[80,0]]; shape.closed=false;
var path=mask.property("ADBE Mask Shape");
path.setValueAtTime(0,shape);
shape.vertices=[[0,0],[0,80]];
path.setValueAtTime(2,shape);
follower.transform.rotation.setValue(15);
'@ | Out-Null
    Command 'layer.select' @{layers=@('Track','Traveler')} | Out-Null
    Click 'followPath'
    Script @'
var c=app.project.activeItem;
if (c.layer("Traveler").transform.position.expression) throw new Error("Unselected path was accepted");
c.layer("Track").property("ADBE Mask Parade").property("Travel Route").property("ADBE Mask Shape").selected=true;
'@ | Out-Null
    Click 'followPath'
    Script @'
var f=app.project.activeItem.layer("Traveler"), t=f.transform, fx=f.property("Effects");
var u=fx.property("Path Progress").property(1), orient=fx.property("Orient to Path").property(1);
u.setValueAtTime(0,0); u.setValueAtTime(1,50); u.setValueAtTime(2,100);
orient.setValueAtTime(0,false); orient.setValueAtTime(1,true);
function check(time,x,y,r) {
    var p=t.position.valueAtTime(time,false), actual=t.rotation.valueAtTime(time,false);
    var delta=((actual-r)%360+540)%360-180;
    if (t.position.expressionError || t.rotation.expressionError || Math.abs(p[0]-x)>0.03 || Math.abs(p[1]-y)>0.03 || Math.abs(delta)>0.03) throw new Error("Wrong path pose: " + p + "; " + actual);
}
check(0,120,60,15);
check(1,100,90,105+Math.atan2(40,60)*180/Math.PI);
check(2,40,60,195);
"PASS: mask following evaluates animated path geometry, transforms to comp space, and orients to the tangent.";
'@
} finally {
    if ($writer -and $reader) {
        if ($window) { try { Command 'scriptui.close' @{window=$window} | Out-Null } catch {} }
        try { Request 'app.quit' @{force=$true} | Out-Null } catch {}
    }
    if ($client) { $client.Dispose() }
}
