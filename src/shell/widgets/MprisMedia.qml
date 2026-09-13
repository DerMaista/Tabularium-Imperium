import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Chip {
    id: root

    readonly property MprisPlayer player: {
        const players = Mpris.players.values;
        for (const candidate of players) {
            if (candidate.isPlaying)
                return candidate;
        }
        return players.length > 0 ? players[0] : null;
    }

    readonly property string trackInfo: {
        if (!root.player)
            return "NO MEDIA ACTIVE";
        const artist = root.player.trackArtist || "";
        const title = root.player.trackTitle || "";
        if (artist.length === 0 && title.length === 0)
            return "NO MEDIA ACTIVE";
        return artist.length > 0 ? artist + " - " + title : title;
    }

    ChipText {
        text: root.trackInfo
        elide: Text.ElideRight
        maximumLineCount: 1
        Layout.maximumWidth: root.screen.width * 0.25
    }
}
