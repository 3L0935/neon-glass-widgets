import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation

    readonly property var cfg: Plasmoid.configuration
    property NeonPalette pal: NeonPalette { cfg: Plasmoid.configuration }

    // Nerd Font glyphs when one is installed (or forced), else the icon theme
    readonly property string nerdFont: {
        const fams = Qt.fontFamilies()
        if (pal.mono.indexOf("Nerd") >= 0) return pal.mono
        for (const f of ["JetBrainsMono Nerd Font", "Symbols Nerd Font", "FiraCode Nerd Font", "Hack Nerd Font"])
            if (fams.indexOf(f) >= 0) return f
        return fams.find(f => f.indexOf("Nerd Font") >= 0) || ""
    }
    readonly property bool useNerdFont: cfg.iconStyle === 1 || (cfg.iconStyle === 0 && nerdFont !== "")

    // ── MPRIS ────────────────────────────────────────────────────────
    // Row 0 of the model is the "multiplexer": it follows whichever player is playing.
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool has: !!player && (player.track || player.artist)
    readonly property string identity: player ? player.identity : ""
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string title: has ? player.track : ""
    readonly property string artist: has ? player.artist : ""
    // YouTube's 4:3 thumbnails are letterboxed: prefer the 16:9 one
    readonly property string art: has ? String(player.artUrl || "").replace("/hqdefault.jpg", "/mqdefault.jpg") : ""
    readonly property real length: has ? player.length : 0
    readonly property real position: has ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    property var players: []          // [{index, identity}] of the real players (rows 1…n)

    function refreshPlayers() {
        const out = [], CONTAINER_ROLE = Qt.UserRole + 1
        for (let i = 1; i < mpris.rowCount(); i++) {
            const p = mpris.data(mpris.index(i, 0), CONTAINER_ROLE)
            if (p) out.push({ index: i, identity: p.identity })
        }
        players = out
    }
    Connections {
        target: mpris
        function onRowsInserted() { root.refreshPlayers() }
        function onRowsRemoved() { root.refreshPlayers() }
    }
    Component.onCompleted: refreshPlayers()

    Timer {   // keep the position fresh: MPRIS players only push it when seeking
        interval: 500; repeat: true; running: root.playing
        onTriggered: root.player && root.player.updatePosition()
    }

    function fmt(us) {
        const s = Math.max(0, Math.floor(us / 1e6))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    function seekTo(frac) { if (has && player.canSeek && length > 0) player.position = Math.round(frac * length) }
    function cycleLoop() {
        if (!player) return
        const L = Mpris.LoopStatus
        if (isMusicCli) player.loopStatus = player.loopStatus === L.None ? L.Track : L.None   // no playlist loop there
        else player.loopStatus = player.loopStatus === L.None ? L.Playlist : player.loopStatus === L.Playlist ? L.Track : L.None
    }
    function next() {
        if (!player) return
        if (isMusicCli) startLoading(upNext.length ? upNext[0].title : "")
        player.Next()
    }

    // one volume step per wheel notch (120 units), whatever the mouse sends; Shift = fine step
    property real wheelAcc: 0
    function wheelVolume(w, osd) {
        if (!player) return
        // Shift often turns a vertical wheel into a horizontal one
        wheelAcc += w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x
        const step = ((w.modifiers & Qt.ShiftModifier) ? cfg.fineVolumeStep : cfg.volumeStep) / 100
        while (Math.abs(wheelAcc) >= 120) {
            const up = wheelAcc > 0
            wheelAcc += up ? -120 : 120
            player.changeVolume(up ? step : -step, osd)
        }
        wheelReset.restart()
    }
    Timer { id: wheelReset; interval: 400; onTriggered: root.wheelAcc = 0 }

    // ── toasts and the "loading" state ───────────────────────────────
    property string toast: ""
    function say(msg) { toast = msg; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3500; onTriggered: root.toast = "" }
    // music-cli's daemon is busy while it downloads the next track: show it
    property bool loading: false
    property string loadingLabel: ""
    Timer { id: loadingTimeout; interval: 120000; onTriggered: root.loading = false }
    function startLoading(label) { loading = true; loadingLabel = label || ""; loadingTimeout.restart() }
    onTitleChanged: { loading = false; refreshQueue() }

    // ── music-cli integration (optional, see extras/music-cli) ───────
    readonly property bool isMusicCli: cfg.musicCli && identity === "music-cli"
    readonly property string helper: cfg.helperCommand || "neonglass-player"
    readonly property string videoId: {
        const m = /\/vi\/([^/]+)\//.exec(art || "")
        return isMusicCli && m ? m[1] : ""
    }
    property bool liked: false
    property var upNext: []           // [{title, artist}]
    property int queueCount: 0
    property var allPlaylists: []     // [{id, title, group}]
    property bool playlistsLoading: false
    property bool refreshing: false

    onIsMusicCliChanged: refreshQueue()
    onVideoIdChanged: { liked = false; if (videoId) sh.run(helper + " is-liked " + videoId) }
    function refreshQueue() {
        if (isMusicCli && cfg.showUpNext) sh.run(helper + " queue 4")
        else { upNext = []; queueCount = 0 }
    }
    function like() { say("…"); sh.run(helper + " like") }
    function reshuffle() { say("…"); sh.run(helper + " reshuffle") }
    function playShortcut(key) { startLoading(""); sh.run(helper + " play " + key) }
    function playId(id, title) {
        if (!/^[A-Za-z0-9_-]+$/.test(id)) return   // ids go into a shell command
        startLoading(title); sh.run(helper + " play-id " + id)
    }
    function loadPlaylists() { playlistsLoading = true; sh.run(helper + " playlists") }
    function refreshMixes() {
        if (refreshing) return
        refreshing = true; say("refreshing…"); sh.run(helper + " refresh")
    }
    function openTui() { sh.run("(" + (cfg.tuiCommand || "kitty -e music-cli") + ") >/dev/null 2>&1 &") }

    P5Support.DataSource {
        id: sh
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = (data.stdout || "").trim()
            const is = (cmd) => source.indexOf(root.helper + " " + cmd) === 0
            if (is("is-liked")) { root.liked = out === "1"; return }
            if (is("queue")) {
                try { const q = JSON.parse(out); root.upNext = q.items || []; root.queueCount = q.count || 0 } catch (e) {}
                return
            }
            if (is("playlists")) {
                root.playlistsLoading = false
                try { root.allPlaylists = JSON.parse(out) } catch (e) { root.say("✗ could not list playlists") }
                return
            }
            if (is("refresh")) { root.refreshing = false; root.say(out); root.refreshQueue(); return }
            if (is("play")) { if (out.indexOf("▶") === 0) root.startLoading(out.slice(2)); else if (out) root.say(out); return }
            if (is("like")) root.liked = out.indexOf("♥") === 0
            if (is("reshuffle")) root.refreshQueue()
            if (out) root.say(out.split("\n").pop())
        }
        // a timestamp comment makes repeated commands distinct sources
        function run(cmd) { connectSource(cmd + " # " + Date.now()) }
    }

    compactRepresentation: Compact {}
    fullRepresentation: Card {}
}
