// Snap the DesktopHealth window flush into the top-right corner of its screen,
// keeping its own (content-sized) width/height. Used after launch and on demand.
(function () {
    var list = workspace.windowList ? workspace.windowList() : workspace.clientList();
    for (var i = 0; i < list.length; i++) {
        var c = list[i];
        if (!c.caption || c.caption.indexOf("DesktopHealth") === -1) continue;

        // Work area for this window's screen (excludes panels).
        var area;
        try { area = workspace.clientArea(KWin.PlacementArea, c); }
        catch (e) {
            try { area = workspace.clientArea(0, c.screen, c.desktop); }
            catch (e2) { area = { x: 0, y: 0, width: workspace.workspaceWidth, height: workspace.workspaceHeight }; }
        }

        var g = c.frameGeometry;
        c.frameGeometry = {
            x: area.x + area.width - g.width,
            y: area.y,
            width: g.width,
            height: g.height
        };
        c.keepBelow = true;
        c.keepAbove = false;
    }
})();
