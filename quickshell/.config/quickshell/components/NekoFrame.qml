import QtQuick
import qs.services

// nekosec only (Neko.enabled): a pink -> lavender -> mint gradient border over the
// box it fills, and optionally two cat ears on its top edge that twitch now and
// then. Drawn over the box's own 1 px border; invisible in every other theme.
//   NekoFrame { anchors.fill: parent; radius: parent.radius; ears: true }
Item {
    id: root
    property real radius: Theme.radius
    property bool ears: false
    property real earWidth: 15
    property real earHeight: 8
    property real lineWidth: 1.6
    property color c1: Theme.accent
    property color c2: Neko.lilac
    property color c3: Neko.mint

    visible: Neko.enabled
    z: 10

    Canvas {
        id: border
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Connections { target: Neko; function onLilacChanged() { border.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, lw = root.lineWidth;
            if (w < 4 || h < 4) return;
            const g = ctx.createLinearGradient(0, 0, w, h);
            g.addColorStop(0, root.c1);
            g.addColorStop(0.55, root.c2);
            g.addColorStop(1, root.c3);
            ctx.strokeStyle = g;
            ctx.lineWidth = lw;
            const r = Math.min(root.radius, h / 2, w / 2);
            ctx.beginPath();
            ctx.roundedRect(lw / 2, lw / 2, w - lw, h - lw, r, r);
            ctx.stroke();
        }
    }

    component Ear: Canvas {
        id: ear
        property bool mirrored: false
        width: root.earWidth
        height: root.earHeight + 2
        y: -root.earHeight + 1
        transformOrigin: mirrored ? Item.BottomLeft : Item.BottomRight
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            ctx.beginPath();
            // a rounded tip leaning outwards
            // a triangle with a rounded tip, leaning a little outwards
            const tx = mirrored ? w * 0.72 : w * 0.28;
            ctx.moveTo(0, h);
            ctx.lineTo(tx - 1.5, 2);
            ctx.quadraticCurveTo(tx, 0, tx + 1.5, 2);
            ctx.lineTo(w, h);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, root.c1);
            g.addColorStop(1, root.c2);
            ctx.fillStyle = g;
            ctx.fill();
        }
        function twitch() { anim.restart(); }
        SequentialAnimation {
            id: anim
            RotationAnimation { target: ear; to: ear.mirrored ? 16 : -16; duration: 90; easing.type: Easing.OutQuad }
            RotationAnimation { target: ear; to: 0; duration: 260; easing.type: Easing.OutBack }
            RotationAnimation { target: ear; to: ear.mirrored ? 8 : -8; duration: 70 }
            RotationAnimation { target: ear; to: 0; duration: 200; easing.type: Easing.OutBack }
        }
    }

    Ear {
        id: leftEar
        visible: root.ears
        x: Math.max(root.radius * 1.1, 10)
    }
    Ear {
        id: rightEar
        visible: root.ears
        mirrored: true
        x: root.width - width - Math.max(root.radius * 1.1, 10)
    }

    Timer {
        running: root.ears && root.visible
        repeat: true
        interval: 6000 + Math.random() * 20000
        onTriggered: {
            (Math.random() < 0.5 ? leftEar : rightEar).twitch();
            interval = 6000 + Math.random() * 20000;
        }
    }
}
