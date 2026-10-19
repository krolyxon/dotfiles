pragma Singleton
import QtQuick
import Quickshell

// fuzzel-style matching shared by PowerMenu and Runner.
Singleton {
    // query chars must appear in order; prefix > word start > contiguous > scattered. q must be lowercase.
    function score(label, q) { return scoreLow(label.toLowerCase(), q) }
    // same, for an already lowercased s (big dmenu lists lowercase once, not per keystroke)
    function scoreLow(s, q) {
        if (q === "") return 1
        if (s.indexOf(q) === 0) return 1000
        var w = s.indexOf(" " + q)
        if (w >= 0) return 500
        if (s.indexOf(q) >= 0) return 300
        var pos = 0, gaps = 0
        for (var i = 0; i < q.length; i++) {
            var f = s.indexOf(q[i], pos)
            if (f < 0) return 0
            gaps += f - pos
            pos = f + 1
        }
        return 100 - gaps
    }
}
