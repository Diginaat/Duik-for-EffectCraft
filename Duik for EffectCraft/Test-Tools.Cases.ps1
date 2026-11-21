# Cases for Test-Tools.ps1. Setup and Check run with `c` bound to the case's composition.
# Steps: 'widgetName' clicks, 'select:A|B' selects layers, @{Script=...} runs code, @{Widget=...; Value=...} sets a field.
@(
    @{
        Name = 'Interpolation'
        Setup = @'
var r = c.layers.addSolid([1,0,0],"Box",20,20,1).transform.rotation;
r.setValueAtTime(0,0); r.setValueAtTime(1,90); r.setValueAtTime(2,0); r.setValueAtTime(3,45);
r.setSelectedAtKey(1,true); r.setSelectedAtKey(2,true);
'@
        Steps = @(@{Widget='easeInfluence'; Value='60'}, 'keyEasyEase', @{Script='var r=app.project.activeItem.layer("Box").transform.rotation; r.setSelectedAtKey(1,false); r.setSelectedAtKey(2,false); r.setSelectedAtKey(3,true);'}, 'keyHold')
        Expect = 'Easy Ease set on 2 key(s).'
        Check = @'
var r = c.layer("Box").transform.rotation;
near(r.keyOutTemporalEase(1)[0].influence, 60, "ease influence");
near(r.keyOutTemporalEase(1)[0].speed, 0, "ease speed");
if (r.keyOutInterpolationType(3) !== KeyframeInterpolationType.HOLD) throw new Error("Hold not set");
near(r.valueAtTime(2.5,false), 0, "held value");
if (r.valueAtTime(0.1,false) >= 9) throw new Error("Ease did not slow the start: " + r.valueAtTime(0.1,false));
'@
    }
    @{
        Name = 'Tween and Freeze'
        Setup = @'
var l = c.layers.addSolid([1,0,0],"Box",20,20,1);
l.transform.position.setValueAtTime(0,[0,0]); l.transform.position.setValueAtTime(2,[100,40]);
l.transform.opacity.setValueAtTime(0,0); l.transform.opacity.setValueAtTime(2,100);
l.transform.rotation.setValueAtTime(0,30); l.transform.rotation.setValueAtTime(0.25,90);
c.time = 0.5;
'@
        Steps = @('select:Box', @{Widget='tweenRatio'; Value='25'}, 'tween', @{Script='app.project.activeItem.time = 3;'}, 'freezePose')
        Check = @'
var t = c.layer("Box").transform;
if (t.position.numKeys !== 4) throw new Error("Expected tween and freeze keys: " + t.position.numKeys);
near(t.position.keyValue(2), [25,10], "tween position");
near(t.opacity.keyValue(2), 25, "tween opacity");
if (t.rotation.numKeys !== 3) throw new Error("Rotation tween wrongly added past its last key");
near(t.rotation.keyValue(3), 90, "frozen rotation");
near(t.position.valueAtTime(3,false), [100,40], "frozen position");
'@
    }
    @{
        Name = 'Snap Sync Clean'
        Setup = @'
var l = c.layers.addSolid([1,0,0],"Box",20,20,1), r = l.transform.rotation, o = l.transform.opacity;
r.setValueAtTime(0.51,10); r.setValueAtTime(1.02,20);
r.setTemporalEaseAtKey(2,[new KeyframeEase(0,70)],[new KeyframeEase(0,70)]);
o.setValueAtTime(0,50); o.setValueAtTime(1,50); o.setValueAtTime(2,50); o.setValueAtTime(3,80);
'@
        Steps = @('select:Box', 'snapKeys', @{Script='var c=app.project.activeItem, s=c.layer("Box").transform.scale; s.setValueAtTime(1,[100,100]); s.setValueAtTime(2,[50,50]); s.setSelectedAtKey(1,true); s.setSelectedAtKey(2,true); c.time=2.5;'}, 'syncKeys', @{Script='var l=app.project.activeItem.layer("Box"); l.transform.scale.selected=false; l.transform.opacity.selected=true;'}, 'cleanKeys')
        Check = @'
var t = c.layer("Box").transform, f = c.frameDuration;
near(t.rotation.keyTime(1), Math.round(0.51/f)*f, "snapped key 1", 1e-6);
near(t.rotation.keyTime(2), Math.round(1.02/f)*f, "snapped key 2", 1e-6);
near(t.rotation.keyInTemporalEase(2)[0].influence, 70, "snapped ease kept");
near(t.scale.keyTime(1), 2.5, "synced first key", 1e-6);
near(t.scale.keyTime(2), 3.5, "synced second key", 1e-6);
near(t.scale.keyValue(2), [50,50], "synced value");
if (t.opacity.numKeys !== 3) throw new Error("Clean kept " + t.opacity.numKeys + " opacity keys");
near(t.opacity.valueAtTime(2.5,false), 65, "cleaned animation");
'@
    }
    @{
        Name = 'Sequence and Exposure'
        Setup = @'
["C","B","A"].forEach(function (n) { c.layers.addSolid([1,1,1],n,10,10,1); });
var r = c.layer("A").transform.rotation;
r.setValueAtTime(0,0); r.setValueAtTime(1,24);
'@
        Steps = @('select:A|B|C', @{Widget='animFrames'; Value='3'}, 'sequenceLayers', @{Script='var c=app.project.activeItem; c.layer("A").transform.rotation.selected=true;'}, @{Widget='animFrames'; Value='2'}, 'exposure')
        Check = @'
var f = c.frameDuration;
near([c.layer("A").inPoint, c.layer("B").inPoint, c.layer("C").inPoint], [0,3*f,6*f], "sequence", 1e-6);
var r = c.layer("A").transform.rotation;
if (!r.expression || r.expressionError) throw new Error("Exposure expression missing " + r.expressionError);
near(r.valueAtTime(3*f,false), 2, "held on twos");
near(r.valueAtTime(4*f,false), 4, "next exposure");
'@
    }
    @{
        Name = 'Copy Paste Animation'
        Setup = @'
var a = c.layers.addSolid([1,0,0],"Source",20,20,1), b = c.layers.addSolid([0,1,0],"Dest",20,20,1);
a.transform.rotation.setValueAtTime(1,10); a.transform.rotation.setValueAtTime(2,50);
a.transform.rotation.setInterpolationTypeAtKey(2,KeyframeInterpolationType.HOLD);
c.time = 1;
'@
        Steps = @('select:Source', 'copyAnim', @{Script='app.project.activeItem.time = 2;'}, 'select:Dest', 'pasteAnim')
        Check = @'
var r = c.layer("Dest").transform.rotation;
if (r.numKeys !== 2) throw new Error("Pasted " + r.numKeys + " keys");
near([r.keyTime(1), r.keyTime(2)], [2,3], "pasted times", 1e-6);
near([r.keyValue(1), r.keyValue(2)], [10,50], "pasted values");
if (r.keyInInterpolationType(2) !== KeyframeInterpolationType.HOLD) throw new Error("Interpolation not pasted");
'@
    }

    @{
        Name = 'Random Swink Spring'
        Setup = @'
var a = c.layers.addSolid([1,0,0],"Rand",20,20,1), b = c.layers.addSolid([1,0,0],"Swing",20,20,1), s = c.layers.addSolid([1,0,0],"Bouncy",20,20,1);
a.transform.position.setValue([100,100]);
var r = s.transform.rotation;
r.setValueAtTime(0,0); r.setValueAtTime(1,90);
r.setInterpolationTypeAtKey(1,KeyframeInterpolationType.LINEAR,KeyframeInterpolationType.LINEAR);
r.setInterpolationTypeAtKey(2,KeyframeInterpolationType.LINEAR,KeyframeInterpolationType.LINEAR);
a.transform.position.selected = true;
'@
        Steps = @(@{Widget='frequency'; Value='2'}, @{Widget='amplitude'; Value='10'}, 'random',
            @{Script='var c=app.project.activeItem; c.layer("Rand").transform.position.selected=false; c.layer("Swing").transform.rotation.selected=true;'}, 'swink',
            @{Script='var c=app.project.activeItem; c.layer("Swing").transform.rotation.selected=false; c.layer("Bouncy").transform.rotation.selected=true;'}, 'spring')
        Expect = 'Spring applied to 1 properties.'
        Check = @'
var p = c.layer("Rand").transform.position;
var v1 = p.valueAtTime(0.1,false), v2 = p.valueAtTime(0.4,false), v3 = p.valueAtTime(0.6,false);
if (p.expressionError || String(v1) !== String(v2) || String(v2) === String(v3)) throw new Error("Random did not hold per tick: " + v1 + " " + v2 + " " + v3);
if (Math.abs(v1[0]-100) > 10 || Math.abs(v1[1]-100) > 10 || v1[0] === v1[1]) throw new Error("Random range or dimensions wrong: " + v1);
var w = c.layer("Swing"), sw = w.transform.rotation;
near(sw.valueAtTime(0.125,false), 10, "swing peak");
w.property("Effects").property("Swink Blink").property(1).setValue(true);
near(sw.valueAtTime(0.05,false), 10, "blink high");
near(sw.valueAtTime(0.3,false), -10, "blink low");
var r = c.layer("Bouncy").transform.rotation, q = 4*Math.PI;
near(r.valueAtTime(0.5,false), 45, "spring before key");
near(r.valueAtTime(1.125,false), 90+90*0.5/Math.exp(5*0.125)/q, "spring overshoot", 0.05);
near(r.valueAtTime(3.5,false), 90, "spring settles", 0.05);
'@
    }
    @{
        Name = 'Curved Wheel and Bake'
        Setup = @'
var w = c.layers.addSolid([1,1,1],"Wheel",100,100,1), p = w.transform.position;
p.setValueAtTime(0,[100,100]); p.setValueAtTime(1,[130,140]); p.setValueAtTime(2,[70,60]);
for (var k = 1; k <= 3; k++) { p.setInterpolationTypeAtKey(k,KeyframeInterpolationType.LINEAR,KeyframeInterpolationType.LINEAR); p.setSpatialTangentsAtKey(k,[0,0,0],[0,0,0]); }
w.transform.rotation.setValue(10);
c.time = 0;
'@
        Steps = @('select:Wheel', @{Widget='wheelCurved'; Value=$true}, @{Widget='wheelRadius'; Value='50'}, 'rollWheel',
            @{Script='var r=app.project.activeItem.layer("Wheel").transform.rotation; if (Math.abs(r.valueAtTime(1,false)-10-180/Math.PI)>0.05) throw new Error("curved wheel " + r.valueAtTime(1,false) + " " + r.expressionError); r.selected=true;'},
            'bakeExpressions')
        Expect = 'Baked 1 expression(s)'
        Check = @'
var r = c.layer("Wheel").transform.rotation;
if (r.expression) throw new Error("Bake left the expression");
near(r.valueAtTime(0.5,false), 10+90/Math.PI, "baked midpoint", 0.05);
near(r.valueAtTime(2,false), 10-180/Math.PI, "baked reverse travel", 0.05);
if (r.numKeys > 6) throw new Error("Bake did not reduce linear runs: " + r.numKeys);
'@
    }
    @{
        Name = 'Toggle and Remove Expressions'
        Setup = @'
var l = c.layers.addSolid([1,1,1],"Expr",10,10,1);
l.transform.rotation.expression = "45"; l.transform.opacity.expression = "50";
'@
        Steps = @('select:Expr', 'toggleExpressions', @{Script='var t=app.project.activeItem.layer("Expr").transform; if (t.rotation.expressionEnabled || t.rotation.value !== 0) throw new Error("toggle failed"); t.opacity.selected=true;'}, 'removeExpressions')
        Check = @'
var t = c.layer("Expr").transform;
if (t.opacity.expression || !t.rotation.expression) throw new Error("Remove did not target only the selected property");
'@
    }

    @{
        Name = 'Connector and Effector'
        Setup = @'
var box = c.layers.addSolid([1,0,0],"Box",20,20,1), dial = c.layers.addNull();
dial.name = "Dial";
var slider = dial.property("ADBE Effect Parade").addProperty("ADBE Slider Control");
slider.property(1).setValue(50);
var r = box.transform.rotation, o = box.transform.opacity;
box.transform.position.setValue([100,100]);
r.setValueAtTime(0,0); r.setValueAtTime(1,90); o.setValueAtTime(0,0); o.setValueAtTime(1,100);
[r,o].forEach(function (p) { for (var k = 1; k <= 2; k++) p.setInterpolationTypeAtKey(k,KeyframeInterpolationType.LINEAR,KeyframeInterpolationType.LINEAR); });
slider.property(1).selected = true;
'@
        Steps = @('setDriver', @{Script='var c=app.project.activeItem; c.layer("Dial").property("Effects").property(1).property(1).selected=false; c.layer("Box").transform.rotation.selected=true;'}, 'connectKeys',
            @{Script='var c=app.project.activeItem, b=c.layer("Box"); b.transform.rotation.selected=false; b.transform.opacity.selected=true;'}, 'effector')
        Expect = @('Driver set.', 'Connected 1 property(ies).', 'Effector ready.')
        Check = @'
var box = c.layer("Box"), r = box.transform.rotation, o = box.transform.opacity;
var s = c.layer("Dial").property("Effects").property(1).property(1);
near(r.valueAtTime(0,false), 45, "connector mid");
s.setValue(100); near(r.valueAtTime(0,false), 90, "connector end");
s.setValue(-30); near(r.valueAtTime(0,false), 0, "connector clamp");
var e = c.layer("Effector");
near(o.valueAtTime(0,false), 100*(1-(Math.sqrt(4000)-50)/150), "effector falloff");
e.transform.position.setValue([105,100]); near(o.valueAtTime(0,false), 100, "effector inside");
e.transform.position.setValue([320,240]); near(o.valueAtTime(0,false), 0, "effector outside");
'@
    }
    @{
        Name = 'Lock Reset Align'
        Setup = @'
var target = c.layers.addSolid([1,1,1],"Target",10,10,1), loose = c.layers.addSolid([1,1,1],"Loose",10,10,1);
var holder = c.layers.addNull(), child = c.layers.addSolid([1,1,1],"Child",10,10,1);
holder.name = "Holder"; holder.transform.anchorPoint.setValue([0,0]); holder.transform.position.setValue([100,100]); holder.transform.rotation.setValue(90);
child.parent = holder; child.transform.rotation.setValue(30); child.transform.scale.setValue([50,70]);
target.transform.position.setValue([200,50]); target.moveToBeginning();
var r = loose.transform.rotation; r.setValueAtTime(0,0); r.setValueAtTime(1,90);
c.time = 0.5; r.selected = true;
'@
        Steps = @('lockProperty', 'select:Child', 'resetTransform', 'select:Target|Loose|Child', 'alignLayers')
        Expect = @('Locked 1 property(ies)', 'Aligned 2 layer(s) to Target.')
        Check = @'
var r = c.layer("Loose").transform.rotation, ct = c.layer("Child").transform;
near([r.valueAtTime(0,false), r.valueAtTime(1,false)], [45,45], "locked");
near(ct.rotation.value, 0, "reset rotation"); near(ct.scale.value, [100,100], "reset scale");
near(c.layer("Loose").transform.position.value, [200,50], "aligned unparented");
near(ct.position.value, [-50,-100], "aligned in parent space");
'@
    }
    @{
        Name = 'Path Pins'
        Setup = @'
var s = c.layers.addShape(); s.name = "Blob";
s.transform.anchorPoint.setValue([0,0]); s.transform.position.setValue([100,100]);
var v = s.property("ADBE Root Vectors Group").addProperty("ADBE Vector Group").property("ADBE Vectors Group");
var item = v.addProperty("ADBE Vector Shape - Group");
var shape = new Shape(); shape.vertices = [[0,0],[50,0],[50,50]]; shape.inTangents = [[0,0],[0,0],[0,0]]; shape.outTangents = [[10,0],[0,0],[0,0]]; shape.closed = false;
item.property("ADBE Vector Shape").setValue(shape);
v.addProperty("ADBE Vector Graphic - Stroke");
var m = c.layers.addSolid([1,1,1],"Masked",100,100,1);
var mask = m.property("ADBE Mask Parade").addProperty("ADBE Mask Atom");
var ms = new Shape(); ms.vertices = [[10,10],[90,10],[50,90]]; ms.closed = true;
mask.property("ADBE Mask Shape").setValue(ms);
item.property("ADBE Vector Shape").selected = true;
'@
        Steps = @('pinPath', @{Script='var c=app.project.activeItem; c.layer("Blob").property("ADBE Root Vectors Group").property(1).property("ADBE Vectors Group").property(1).property("ADBE Vector Shape").selected=false; c.layer("Masked").property("ADBE Mask Parade").property(1).property("ADBE Mask Shape").selected=true;'}, 'pinPath')
        Expect = @('Pinned 3 vertices.')
        Check = @'
var path = c.layer("Blob").property("ADBE Root Vectors Group").property(1).property("ADBE Vectors Group").property(1).property("ADBE Vector Shape");
var p1 = c.layer("Pin - Blob 1"), p2 = c.layer("Pin - Blob 2"), h = c.layer("Pin - Blob 1 Out");
if (!p1 || !p2 || !h || h.parent !== p1 || c.layer("Pin - Blob 2 Out")) throw new Error("Pins or handles missing");
near(p2.transform.position.value, [150,100], "pin placement");
var rest = path.value;
near(rest.vertices[1], [50,0], "rest vertex"); near(rest.outTangents[0], [10,0], "rest tangent");
p2.transform.position.setValue([200,80]);
p1.transform.rotation.setValue(90);
var moved = path.value;
near(moved.vertices[1], [100,-20], "pinned vertex follows");
near(moved.outTangents[0], [0,10], "handle rotates with pin");
var mp = c.layer("Masked").property("ADBE Mask Parade").property(1).property("ADBE Mask Shape");
c.layer("Pin - Masked 3").transform.position.setValue([160,170]);
var mv = mp.value;
if (!mv.closed) throw new Error("Mask closed flag lost");
near(mv.vertices[2], [50,100], "mask pin follows");
'@
    }

    @{
        Name = 'Controllers Rename Notes'
        Setup = @'
var target = c.layers.addNull(); target.name = "Wrist";
var lower = c.layers.addSolid([0,1,0],"Lower",80,10,1), upper = c.layers.addSolid([1,0,0],"Upper",100,10,1);
upper.transform.anchorPoint.setValue([0,5]); lower.transform.anchorPoint.setValue([0,5]);
upper.transform.position.setValue([60,80]); lower.transform.position.setValue([160,80]);
target.transform.position.setValue([240,80]);
'@
        Steps = @('select:Upper|Lower|Wrist', 'buildIkFk', 'select:Upper', @{Widget='controllerShape'; Value=1}, 'addControls',
            'select:Upper|Wrist', @{Widget='renamePrefix'; Value='L '}, 'renameLayers',
            @{Widget='compNotes'; Value='Arm rig, left side.'}, 'saveNotes')
        Expect = @('IK/FK ready.', 'Created 1 controller(s).', 'Renamed 2 layer(s).', 'Saved notes')
        Check = @'
var ctrl = c.layer("Ctrl - Upper");
if (!ctrl || ctrl.nullLayer || !ctrl.property("ADBE Root Vectors Group").property("Circle")) throw new Error("Circle controller missing");
near(ctrl.transform.position.value, [60,80], "controller placement");
if (!c.layer("L Upper") || !c.layer("L Wrist") || c.layer("Upper")) throw new Error("Rename failed");
var elbow = c.layer("Lower").transform.position, rot = c.layer("L Upper").transform.rotation;
if (elbow.expression.indexOf('layer("L Wrist")') < 0 || elbow.expression.indexOf('"Upper"') >= 0) throw new Error("References not retargeted");
if (rot.expression.split("\n")[0].indexOf('"L Upper"') < 0) throw new Error("Rig metadata not retargeted");
c.layer("L Wrist").transform.position.setValue([200,140]);
var probe = c.layers.addNull().transform.position;
probe.expression = 'var l=thisComp.layer("Lower"); l.toComp([80,5]);';
near(probe.value, [200,140], "renamed rig still solves", 0.05);
if (c.comment !== "Arm rig, left side.") throw new Error("Notes not saved: " + c.comment);
'@
    }

    @{
        Name = 'Chain Templates'
        Setup = ''
        Steps = @(@{Widget='limbTemplate'; Value=2}, 'buildLimbTemplate', @{Widget='limbTemplate'; Value=3}, 'buildLimbTemplate', 'buildLimbTemplate')
        Expect = @('Spine ready.', 'Tail ready.', 'Tail 2 ready.')
        Check = @'
function world(name) {
    var probe = c.layers.addNull().transform.position;
    probe.expression = 'var l=thisComp.layer(' + JSON.stringify(name) + '); l.toComp([0,0]);';
    var v = probe.value; probe.propertyGroup(2).remove(); return v;
}
if (c.layer("Spine - Head").parent !== c.layer("Spine - Neck") || c.layer("Spine - Hips").parent) throw new Error("Spine hierarchy wrong");
near(world("Spine - Head"), [160, 120+240*(0.18-4*0.09)], "head placement", 0.01);
var root = c.layer("Tail - Tail 1"), tip = c.layer("Tail - Tail 5");
if (tip.parent !== c.layer("Tail - Tail 4") || !root.property("Effects").property("Delay Frames") || !c.layer("Tail 2 - Tail 1")) throw new Error("Tail template wrong");
if (!(root.index < c.layer("Tail - Tail 2").index && c.layer("Tail - Tail 4").index < tip.index)) throw new Error("Tail order wrong");
near(world("Tail - Tail 5"), [160+240*(-0.25+0.4), 120], "tail tip", 0.01);
root.transform.rotation.setValueAtTime(0,0); root.transform.rotation.setValueAtTime(1,90);
var lag = c.layer("Tail - Tail 2").transform.rotation.valueAtTime(1,false);
if (!(lag < -1) || c.layer("Tail - Tail 2").transform.rotation.expressionError) throw new Error("Tail overlap missing: " + lag);
'@
    }

    @{
        Name = 'Cameras'
        Setup = @'
var near2 = c.layers.addSolid([1,0,0],"Near",20,20,1), far = c.layers.addSolid([0,0,1],"Far",20,20,1);
near2.transform.position.setValue([200,120]); far.transform.position.setValue([200,120]);
'@
        Steps = @('select:Near|Far', 'camera2d', @{Script='var c=app.project.activeItem; for (var i=1;i<=c.numLayers;i++) c.layer(i).selected=false;'}, 'rigCamera')
        Expect = @('2D camera ready.', 'Camera rig ready.')
        Check = @'
var cam = c.layer("2D Camera"), n = c.layer("Near").transform, f = c.layer("Far");
f.property("Effects").property("Camera Depth").property(1).setValue(50);
near(n.position.value, [200,120], "2D camera rest");
cam.transform.position.setValue([260,120]);
near(n.position.value, [100,120], "full parallax"); near(f.transform.position.value, [150,120], "half parallax");
cam.transform.position.setValue([160,120]); cam.property("Effects").property("Zoom").property(1).setValue(200);
near(n.position.value, [240,120], "zoom spreads"); near(n.scale.value, [200,200], "zoom scales");
near(f.transform.scale.value, [150,150], "zoom depth");
cam.property("Effects").property("Zoom").property(1).setValue(100); cam.transform.rotation.setValue(90);
near(n.position.value, [160,80], "camera rotation"); near(n.rotation.value, -90, "layer counter-rotation");
var camera = c.layer("Camera"), root = c.layer("Camera Root"), t = camera.transform;
if (!(camera instanceof CameraLayer) || c.layer("Camera Body").parent !== root || c.layer("Camera Target").parent !== root) throw new Error("Rig hierarchy wrong");
var p0 = t.position.value, a0 = t.pointOfInterest.value;
near(a0, [160,120,0], "target rest", 0.01);
root.transform.position.setValue([210,120,0]);
near(t.position.value, [p0[0]+50,p0[1],p0[2]], "root trucks camera", 0.01);
root.transform.position.setValue([160,120,0]); root.transform.yRotation.setValue(90);
var orbit = t.position.value;
near([orbit[0], orbit[1]], [160+p0[2], 120], "root orbits camera", 0.05);
near(t.pointOfInterest.value, [160,120,0], "orbit keeps target", 0.01);
'@
    }

    @{
        Name = 'Trail and Move Away'
        Setup = @'
var dot = c.layers.addSolid([1,0,0],"Dot",10,10,1), p = dot.transform.position;
p.setValueAtTime(0,[0,50]); p.setValueAtTime(1,[240,50]);
for (var k = 1; k <= 2; k++) p.setInterpolationTypeAtKey(k,KeyframeInterpolationType.LINEAR,KeyframeInterpolationType.LINEAR);
var hub = c.layers.addNull(); hub.name = "Hub"; hub.transform.anchorPoint.setValue([0,0]); hub.transform.position.setValue([100,100]);
var petal = c.layers.addSolid([1,1,1],"Petal",10,10,1); petal.parent = hub; petal.transform.position.setValue([30,40]);
'@
        Steps = @('select:Dot', 'motionTrail', 'select:Petal', 'moveAway')
        Expect = @('Created 1 motion trail(s).', 'Move Away applied to 1 properties.')
        Check = @'
var trail = c.layer("Trail - Dot"), path = trail.property("ADBE Root Vectors Group").property(1).property("ADBE Vectors Group").property(1).property("ADBE Vector Shape");
var v = path.valueAtTime(0.5,false).vertices;
if (v.length !== 12) throw new Error("Trail sample count " + v.length);
near(v[0], [120,50], "trail head"); near(v[11], [10,50], "trail tail");
var petal = c.layer("Petal");
petal.property("Effects").property("Move Away").property(1).setValue(50);
near(petal.transform.position.value, [60,80], "moved away from parent");
'@
    }
)
