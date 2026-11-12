pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player the bar shows: the one playing (Spotify first), else the last
// one that played, else Spotify, else any.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastActive: null

    readonly property var player: {
        const playing = players.filter(p => p.isPlaying);
        const spotify = p => (p.identity || "").toLowerCase().includes("spotify");
        return playing.find(spotify) ?? playing[0]
            ?? (players.includes(lastActive) ? lastActive : null)
            ?? players.find(spotify) ?? players[0] ?? null;
    }
    onPlayerChanged: if (player && player.isPlaying) lastActive = player

    readonly property bool active: !!player && player.isPlaying
    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string art: player ? (player.trackArtUrl || "") : ""

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function next() { if (player && player.canGoNext) player.next(); }
    function previous() { if (player && player.canGoPrevious) player.previous(); }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
