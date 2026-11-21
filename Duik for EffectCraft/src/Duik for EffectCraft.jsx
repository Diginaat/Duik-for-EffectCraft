// One dockable EffectCraft panel; the bundle includes all section implementations.
(function (host) {
    #include "Icons.jsxinc"
    #include "Rigging.jsxinc"
    #include "Bezier.jsxinc"
    #include "Armature.jsxinc"
    #include "Constraints.jsxinc"
    #include "Animation.jsxinc"
    #include "Automation.jsxinc"
    #include "Layers.jsxinc"
    #include "Camera.jsxinc"

    var ui = host instanceof Panel ? host : new Window("palette", "Duik for EffectCraft");
    ui.orientation = "column";
    ui.alignChildren = ["fill", "top"];
    // Icon toolbar instead of text tabs, so the panel stays usable when docked narrow.
    var header = ui.add("group");
    header.alignChildren = ["left", "center"];
    var bar = header.add("group", undefined, undefined, { name: "duikTabs" });
    bar.spacing = 2;
    var title = header.add("statictext", undefined, "", { name: "sectionTitle" });
    title.preferredSize = [110, 20];
    var pages = ui.add("group");
    pages.orientation = "stack";
    pages.alignChildren = ["fill", "top"];

    var sections = [], current = null;
    function show(section) {
        current = section;
        sections.forEach(function (s) { s.page.visible = s === section; });
        title.text = section.label;
        sections.forEach(function (s) { s.button.notify("onDraw"); });
        ui.layout.layout(true);
    }
    function section(label, name, build) {
        var page = pages.add("group", undefined, { name: name + "Page" });
        page.orientation = "column";
        page.alignChildren = ["fill", "top"];
        build(page);
        var entry = { label: label, page: page };
        entry.button = addIconButton(bar, label, name, function () { return current === entry; });
        entry.button.onClick = function () { show(entry); };
        sections.push(entry);
    }

    section("Rigging", "tabRigging", buildRiggingTab);
    section("Armature", "tabArmature", buildArmatureTab);
    section("Constraints", "tabConstraints", buildConstraintsTab);
    section("Animation", "tabAnimation", buildAnimationTab);
    section("Automation", "tabAutomation", buildAutomationTab);
    section("Layers", "tabLayers", buildLayersTab);
    section("Camera", "tabCamera", buildCameraTab);
    show(sections[0]);
    if (ui instanceof Window) ui.show();
})(this);
