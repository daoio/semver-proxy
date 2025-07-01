// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type Client is address;

/**
 * @notice Library that defines methods for Client's interactions with the proxy.
 *         That is, allows to "subscribe" to specific versions of the implementation
 *         and "unsubscribe" from them.
 */
library Clients {
    error ClientIsntSubscribed();

    function isSubscribed(
        mapping(Client => address) storage subscribedClients,
        Client client
    ) internal view returns (bool, address) {
        address release = subscribedClients[client];

        return release != address(0) ? (true, release) : (false, address(0));
    }

    /**
     * @notice Store {release} value for a {client} key
     *         inside {subscribedClients} storage map.
     */
    function subscribe(
        mapping(Client => address) storage subscribedClients,
        Client client,
        address release
    ) internal {
        subscribedClients[client] = release;
    }

    /**
     * @notice Remove {release} value for a {client} key
     *         inside {subscribedClients} storage map.
     */
    function unsubscribe(
        mapping(Client => address) storage subscribedClients,
        Client client
    ) internal {
        (bool subscribed, ) = isSubscribed(subscribedClients, client);
        if (!subscribed) revert ClientIsntSubscribed();

        subscribedClients[client] = address(0);
    }
}
