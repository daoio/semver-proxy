// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type Client is address;

/// @notice Defines methods for clients.
library Clients {
    error ClientIsntSubscribed();

    function isSubscribed(
        mapping(Client => address) storage subscribedClients,
        Client client
    ) internal view returns (bool, address) {
        address release = subscribedClients[client];

        return release != address(0) ? (true, release) : (false, address(0));
    }

    /// @notice TODO: describe
    function subscribe(
        mapping(Client => address) storage subscribedClients,
        Client client,
        address release
    ) internal {
        subscribedClients[client] = release;
    }

    /// @notice TODO: describe
    function unsubscribe(
        mapping(Client => address) storage subscribedClients,
        Client client
    ) internal {
        (bool subscribed, ) = isSubscribed(subscribedClients, client);
        if (!subscribed) revert ClientIsntSubscribed();

        subscribedClients[client] = address(0);
    }
}
