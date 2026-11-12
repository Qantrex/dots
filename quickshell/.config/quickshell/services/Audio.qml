pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire: output/input volume, device lists, and the privacy state
// (mic, camera and screen share in use).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    // Hardware devices only (no app streams), for the device pickers.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio
                                                                 && !(n.name || "").endsWith(".monitor"))
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isSink && n.isStream && n.audio)

    // Privacy. The mic counts as "in use" when an app stream records from it.
    readonly property var micUsers: micTracker.linkGroups
        .filter(g => g.target && g.target.isStream)
        .map(g => appName(g.target))
    readonly property bool micInUse: micUsers.length > 0
    // xdg-desktop-portal-hyprland creates an "xdph-streaming-*" node while sharing.
    readonly property bool screenShared: Pipewire.nodes.values.some(n => (n.name || "").startsWith("xdph"))
    readonly property bool cameraInUse: cameraTrackers.instances.some(t => t.linkGroups.length > 0)

    signal userChange(string what)   // the OSD shows these

    function appName(node) {
        if (!node) return "";
        const p = node.properties || {};
        return p["application.name"] || node.description || node.nickname || node.name || "";
    }
    function deviceName(node) {
        if (!node) return "";
        return node.description || node.nickname || node.name || "";
    }

    function setVolume(v) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.0, v));
        userChange("volume");
    }
    function step(delta) { setVolume(Math.round((volume + delta) * 100) / 100); }
    function toggleMute() {
        if (!ready) return;
        sink.audio.muted = !sink.audio.muted;
        userChange("volume");
    }
    function setMicVolume(v) {
        if (!source || !source.audio) return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1.0, v));
    }
    function toggleMic() {
        if (!source || !source.audio) return;
        source.audio.muted = !source.audio.muted;
        userChange("mic");
    }
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function setSource(node) { Pipewire.preferredDefaultAudioSource = node; }

    // Volume and mute only update for tracked nodes.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks).concat(root.sources).concat(root.streams)
    }

    PwNodeLinkTracker {
        id: micTracker
        node: root.source
    }

    Variants {
        id: cameraTrackers
        model: Pipewire.nodes.values.filter(n => !n.isStream && !n.audio
                                            && (n.properties || {})["media.class"] === "Video/Source"
                                            && !(n.name || "").startsWith("xdph"))
        PwNodeLinkTracker {
            required property var modelData
            node: modelData
        }
    }
}
