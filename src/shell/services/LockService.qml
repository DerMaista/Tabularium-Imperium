pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

import qs.config

Singleton {
    id: root

    property bool shouldLock: false
    property bool secure: false

    property bool previewing: false

    property bool verifying: false

    readonly property bool active: root.shouldLock || root.previewing

    function beginVerify() {
        root.resetAttempt();
        root.verifying = true;
        root.previewing = true;
    }

    function cancelPreview() {
        root.previewing = false;
        root.verifying = false;
        root.resetPhases();
        root.resetAttempt();
    }

    function finishVerify(ok) {
        root.message = ok ? "PAM OK · SERVICE \"" + root.pamConfig + "\"" : root.message;
        root.messageIsError = !ok;
        if (ok)
            verifyTimer.restart();
    }

    Timer {
        id: verifyTimer

        interval: 2000
        repeat: false

        onTriggered: root.cancelPreview()
    }

    function engage() {
        if (root.shouldLock)
            return;
        root.resetAttempt();
        root.failures = 0;
        root.lockoutUntil = 0;
        root.shouldLock = true;
    }

    readonly property int paneDuration: 620
    readonly property int dialDuration: 700

    property bool panesClosed: false
    property bool dialJoined: false
    property bool unlocking: false

    function resetPhases() {
        root.panesClosed = false;
        root.dialJoined = false;
    }

    function surfaceReady() {
        if (root.unlocking || root.panesClosed)
            return;
        root.closePanes();
    }

    function closePanes() {
        root.panesClosed = true;
        joinTimer.restart();
    }

    Timer {
        id: joinTimer

        interval: root.paneDuration
        repeat: false

        onTriggered: {
            root.dialJoined = true;
        }
    }

    function beginUnlock() {
        if (root.unlocking)
            return;
        root.unlocking = true;
        root.indicatorState = "idle";
        root.arcSweep = 0;

        unlockTurnTimer.restart();
    }

    Timer {
        id: unlockTurnTimer

        interval: root.dialDuration
        repeat: false

        onTriggered: {
            root.dialJoined = false;
            root.panesClosed = false;
            unlockPaneTimer.restart();
        }
    }

    Timer {
        id: unlockPaneTimer

        interval: root.paneDuration
        repeat: false

        onTriggered: root.release()
    }

    function release() {
        const wasLocked = root.shouldLock;

        root.shouldLock = false;
        root.previewing = false;
        root.verifying = false;
        root.unlocking = false;
        root.indicatorState = "idle";
        root.arcSweep = 0;
        root.resetPhases();
        root.resetAttempt();
        root.failures = 0;
        root.lockoutUntil = 0;

        if (wasLocked)
            root.beginFadeIn();
    }

    property string password: ""
    property string message: ""
    property bool messageIsError: false

    readonly property bool authenticating: pam.active

    property int failures: 0
    property real lockoutUntil: 0

    readonly property bool lockedOut: root.lockoutRemaining > 0
    property int lockoutRemaining: 0

    function resetAttempt() {
        root.password = "";
        root.message = "";
        root.messageIsError = false;
    }

    property real arcStart: 0
    property real arcSweep: 0

    property string indicatorState: "idle"

    onPasswordChanged: {
        if (root.authenticating)
            return;

        if (root.password.length === 0) {
            root.arcSweep = 0;
            root.indicatorState = "cleared";
            return;
        }

        root.arcStart = Math.random() * 360;
        root.arcSweep = 40 + Math.random() * 30;
        root.indicatorState = "input";
    }

    function submit() {
        if (pam.active || root.lockedOut || root.password.length === 0)
            return;

        if (root.previewing && !root.verifying) {
            root.beginUnlock();
            return;
        }

        root.message = "";
        root.messageIsError = false;
        root.indicatorState = "verifying";
        if (!root.startPam()) {
            root.message = "NO PAM SERVICE — TRIED " + root.pamCandidates.join(", ").toUpperCase();
            root.messageIsError = true;
        }
    }

    function onFailure(text) {
        root.indicatorState = "wrong";
        root.arcSweep = 0;
        root.password = "";
        root.message = text;
        root.messageIsError = true;

        if (root.verifying)
            return;

        root.failures++;
        if (root.failures < Config.lockMaxFailures)
            return;

        const over = root.failures - Config.lockMaxFailures + 1;
        root.lockoutUntil = Date.now() + Config.lockoutSeconds * 1000 * over;
        root.tickLockout();
    }

    Timer {
        id: lockoutTimer

        repeat: false

        onTriggered: root.tickLockout()
    }

    function tickLockout() {
        const remaining = root.lockoutUntil - Date.now();
        if (remaining <= 0) {
            root.lockoutRemaining = 0;
            root.message = "";
            root.messageIsError = false;
            lockoutTimer.stop();
            return;
        }

        root.lockoutRemaining = Math.ceil(remaining / 1000);
        root.message = "LOCKED OUT FOR " + root.lockoutRemaining + "S";
        root.messageIsError = true;
        lockoutTimer.interval = Math.min(1000, remaining);
        lockoutTimer.restart();
    }

    readonly property var pamCandidates: ["blueshell", "swaylock", "login"]

    property int pamCandidate: 0

    readonly property string pamConfig: pam.config

    function startPam() {
        for (let i = root.pamCandidate; i < root.pamCandidates.length; i++) {
            pam.config = root.pamCandidates[i];

            if (pam.start()) {
                root.pamCandidate = i;
                return true;
            }

            console.warn("lock: PAM service \"" + pam.config + "\" did not start" + (i + 1 < root.pamCandidates.length ? "; trying \"" + root.pamCandidates[i + 1] + "\"" : "") + ". Add security.pam.services.blueshell to your NixOS config.");
        }
        return false;
    }

    PamContext {
        id: pam

        config: "blueshell"
        configDirectory: "/etc/pam.d"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }

        onMessageChanged: {
            if (message.length === 0 || responseRequired)
                return;
            root.message = message.toUpperCase();
            root.messageIsError = messageIsError;
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                if (root.verifying) {
                    root.finishVerify(true);
                    return;
                }
                root.beginUnlock();
                return;
            }
            if (result === PamResult.MaxTries) {
                root.onFailure("TOO MANY ATTEMPTS");
                return;
            }
            root.onFailure("AUTHENTICATION FAILED");
        }

        onError: err => root.onFailure("PAM ERROR: " + PamError.toString(err).toUpperCase())
    }

    IdleMonitor {
        // Caffeine takes the idle lock out of the loop entirely: while it is on,
        // there is no timeout to reach, not a longer one.
        enabled: Config.lockIdleTimeout > 0 && !root.active && !CaffeineService.active
        timeout: Config.lockIdleTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle)
                root.requestLock(false);
        }
    }

    property var flyoutEntries: []
    property bool flyoutActive: false
    property int flyoutReady: 0

    readonly property int flyoutExpected: Quickshell.screens.length

    signal flyOut

    readonly property int flyDuration: 650
    readonly property int staggerStep: 60

    property string flyoutIntent: "lock"

    function requestLock(animate) {
        root.begin("lock", animate);
    }

    function requestPreview() {
        if (root.previewing) {
            root.cancelPreview();
            return;
        }
        root.begin("preview", true);
    }

    function begin(intent, animate) {
        if (root.shouldLock)
            return;

        if (fadeInCleanup.running) {
            fadeInCleanup.stop();
            root.clearFlyout();
        }

        if (root.flyoutActive) {
            if (intent === "lock")
                root.flyoutIntent = "lock";
            return;
        }

        root.flyoutIntent = intent;

        if (!animate || !Config.lockFlyout || !BackendService.connected) {
            root.finishFlyout();
            return;
        }

        BackendService.sendRequest("workspaces.clients", null, response => {
            if (response.error || !response.result) {
                root.finishFlyout();
                return;
            }

            const clients = response.result.clients || [];
            if (clients.length === 0) {
                root.finishFlyout();
                return;
            }

            root.flyoutEntries = clients;
            root.flyoutReady = 0;
            root.flyoutActive = true;
            captureTimeout.restart();
        });
    }

    function finishFlyout() {
        if (root.flyoutIntent === "preview") {
            root.previewing = true;
            return;
        }
        root.engage();
    }

    function noteCaptured() {
        root.flyoutReady++;
        if (root.flyoutReady >= root.flyoutExpected)
            root.startFlyout();
    }

    function startFlyout() {
        if (!root.flyoutActive || flyTimer.running)
            return;

        captureTimeout.stop();
        root.flyOut();

        const perMonitor = {};
        let most = 0;
        for (const entry of root.flyoutEntries) {
            perMonitor[entry.monitor] = (perMonitor[entry.monitor] || 0) + 1;
            most = Math.max(most, perMonitor[entry.monitor]);
        }

        root.flyoutSpan = root.flyDuration + root.staggerStep * Math.max(0, most - 1);
        flyTimer.interval = root.flyoutSpan;
        flyTimer.restart();
    }

    property int flyoutSpan: 800

    signal fadeIn

    function beginFadeIn() {
        if (!root.flyoutActive)
            return;
        root.fadeIn();
        fadeInCleanup.restart();
    }

    Timer {
        id: fadeInCleanup

        interval: root.flyoutSpan + 120
        repeat: false

        onTriggered: root.clearFlyout()
    }

    function clearFlyout() {
        root.flyoutActive = false;
        root.flyoutEntries = [];
        root.flyoutReady = 0;
    }

    Timer {
        id: captureTimeout

        interval: 700
        repeat: false

        onTriggered: {
            console.warn("lock: no screen capture within " + interval + "ms; locking without the animation");
            root.startFlyout();
        }
    }

    Timer {
        id: flyTimer

        repeat: false

        onTriggered: {
            root.closePanes();
            handoffTimer.restart();
        }
    }

    Timer {
        id: handoffTimer

        interval: root.paneDuration
        repeat: false

        onTriggered: {
            const wasPreview = root.flyoutIntent === "preview";
            root.finishFlyout();

            if (wasPreview)
                flyoutCleanup.restart();
        }
    }

    Timer {
        id: flyoutCleanup

        interval: 250
        repeat: false

        onTriggered: root.clearFlyout()
    }

    function reportState() {
        if (!BackendService.connected)
            return;
        BackendService.sendRequest("lock.state", {
            "locked": root.shouldLock,
            "secure": root.secure
        });
    }

    onShouldLockChanged: {
        if (!root.shouldLock)
            root.resetAttempt();
        root.reportState();
    }

    onSecureChanged: root.reportState()

    Connections {
        target: BackendService

        function onLockEvent(data) {
            if (!data || !data.locked)
                return;
            root.requestLock(data.source === "user" || data.source === "logind");
        }

        function onLinkUp() {
            root.reportState();
        }
    }

    Component.onCompleted: {
        if (Config.lockOnStartup)
            Qt.callLater(root.engage);
    }
}
