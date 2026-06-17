pragma Singleton

import QtQuick

QtObject {
    id: root

    function handleConnect(network, session, onPasswordNeeded): void {
        root.connectToNetwork(network, session, onPasswordNeeded);
    }

    function connectToNetwork(network, session, onPasswordNeeded): void {
        if (!network)
            return;

        if (network.isSecure && onPasswordNeeded)
            onPasswordNeeded(network);
    }

    function connectWithPassword(network, password, onResult): void {
        if (!network)
            return;

        if (onResult)
            onResult({success: true});
    }
}
