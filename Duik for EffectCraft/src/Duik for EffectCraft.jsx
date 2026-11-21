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
    // Two rows keep the full tab names readable in a narrow dock.
    var header = ui.add("group", undefined, undefined, { name: "duikHeader" });
    header.orientation = "column";
    header.alignChildren = ["left", "top"];
    header.spacing = 3;
    var heading = header.add("group");
    heading.alignChildren = ["left", "center"];
    var title = heading.add("statictext", undefined, "", { name: "sectionTitle" });
    title.preferredSize = [110, 20];
    var toggle = addDisplayButton(heading, "Toggle Icons / Text", "displayMode");
    var bar = header.add("group", undefined, undefined, { name: "duikTabs" });
    bar.orientation = "column";
    bar.alignChildren = ["left", "top"];
    bar.spacing = 2;
    var tabRows = [bar.add("group"), bar.add("group")];
    tabRows.forEach(function (row) { row.spacing = 3; });
    var pages = ui.add("group");
    pages.orientation = "stack";
    pages.alignment = ["fill", "fill"];
    pages.alignChildren = ["fill", "top"];

    var sections = [], current = null, picker, settingsStatus;
    var preferences = "Duik for EffectCraft", modeKey = "DisplayMode", mode = "text";
    try {
        if (app.settings.haveSetting(preferences, modeKey) && app.settings.getSetting(preferences, modeKey) === "icons") mode = "icons";
    } catch (error) { /* Text remains usable if settings are unavailable. */ }

    function applyMode(value, remember) {
        mode = value;
        if (remember) {
            try {
                app.settings.saveSetting(preferences, modeKey, mode);
                settingsStatus.text = "Saved.";
            } catch (error) {
                settingsStatus.text = "Applied for this panel session only.";
            }
        }
        picker.selection = mode === "icons" ? 0 : 1;
        toggle.helpTip = (mode === "icons" ? "Switch to Text mode" : "Switch to Icons mode");
        renderDisplayButtons(mode === "icons");
        ui.layout.layout(true);
    }
    toggle.onClick = function () { applyMode(mode === "icons" ? "text" : "icons", true); };

    function show(section) {
        current = section;
        sections.forEach(function (s) { s.page.visible = s === section; });
        title.text = section.label;
        if (mode === "icons") sections.forEach(function (s) { s.button.notify("onDraw"); });
        ui.layout.layout(true);
    }
    function section(label, name, build) {
        var page = pages.add("group", undefined, { name: name + "Page" });
        page.orientation = "column";
        page.alignChildren = ["fill", "top"];
        build(page);
        var entry = { label: label, page: page };
        entry.button = addDisplayButton(tabRows[Math.floor(sections.length / 4)], label, name, function () { return current === entry; });
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
    section("Settings", "tabSettings", function (page) {
        var row = page.add("group");
        row.add("statictext", undefined, "Button display");
        picker = row.add("dropdownlist", undefined, ["Icons", "Text"], { name: "displayPicker" });
        picker.onChange = function () {
            if (!picker.selection) return;
            var choice = picker.selection.index === 0 ? "icons" : "text";
            if (choice !== mode) applyMode(choice, true);
        };
        page.add("statictext", undefined, "Icons show names when you hover. Input labels stay visible.", { multiline: true }).preferredSize = [280, 35];
        settingsStatus = page.add("statictext", undefined, "", { name: "settingsStatus" });
    });

    function addDocsFooter() {
        var links = [
            { label: "Documentation", name: "openDocs", url: "https://www.diginaat.com/tools/effectcraft/duik/", title: "Duik Documentation" },
            { label: "GitHub", name: "openGitHub", url: "https://github.com/Diginaat/Duik-for-EffectCraft", title: "Duik for EffectCraft on GitHub" }
        ];
        var footer = ui.add("group", undefined, undefined, { name: "duikFooter" });
        footer.orientation = "column";
        footer.alignChildren = ["fill", "top"];
        var buttons = footer.add("group");
        buttons.alignChildren = ["fill", "center"];
        var docsLink = footer.add("edittext", undefined, links[0].url, { name: "docsLink", readonly: true });
        docsLink.characters = links[0].url.length;
        docsLink.visible = false;
        var docsStatus = footer.add("statictext", undefined, "", { name: "docsStatus" });
        docsStatus.visible = false;
        links.forEach(function (link) {
            var button = buttons.add("button", undefined, link.label, { name: link.name });
            button.helpTip = link.label + ": " + link.url;
            button.onClick = function () { open(link); };
        });
        function open(link) {
            docsLink.text = link.url;
            docsLink.visible = true;
            docsStatus.visible = true;
            try {
                // Open a local redirect using the host's permission-checked File API.
                // Keep it in the temp folder so the browser can read it asynchronously.
                var temp = Folder.temp;
                if (!temp) throw new Error("Temporary folder unavailable.");
                var launch = new File(temp.fsName + "/duik-link-" + new Date().getTime() + "-" + Math.floor(Math.random() * 1000000) + ".html");
                if (!launch.open("w")) throw new Error("Could not prepare link.");
                try {
                    if (launch.write('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=' + link.url + '"><title>' + link.title + '</title><a href="' + link.url + '">Open ' + link.title + '</a>') === false) {
                        throw new Error("Could not write link.");
                    }
                } finally {
                    launch.close();
                }
                if (!launch.execute()) throw new Error("Could not open link.");
                docsStatus.text = "Opening " + link.title + "…";
            } catch (error) {
                docsStatus.text = "Copy the link above into your browser.";
                docsLink.active = true;
            }
            ui.layout.layout(true);
        }
    }
    addDocsFooter();
    applyMode(mode, false);
    show(sections[0]);
    if (ui instanceof Window) ui.show();
})(this);
