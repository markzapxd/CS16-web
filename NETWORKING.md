# Browser networking

With `IP` unset or empty, each websocket peer advertises an ICE host address derived from that request's HTTP `Host` (the browser's websocket URL). IPv4 and IPv6 literals are used directly; DNS names are resolved by the server's normal resolver, with a two-second timeout. The first resolved address of each family is used. If resolution fails, ordinary local-interface ICE gathering remains enabled. No external public-IP discovery service is contacted. DNS queries still go to the server's configured DNS resolver.

A nonempty `IP` environment variable overrides automatic selection for all peers, preserving explicit deployment configuration. Leave it empty for automatic mode. Each peer has its own WebRTC API, codecs, interceptors, and ICE settings; peers share the configured UDP mux rather than mutating global ICE settings.

## Reachability requirements

- Publish and allow the configured `PORT` over UDP, retaining the same external port. HTTP/WebSocket reachability alone is not enough.
- For LAN access, open the site using the server's LAN address or a DNS name that resolves to it. `localhost` only works for browsers on that same machine.
- For Internet access behind NAT, forward the UDP port to the server. Automatic selection advertises the URL address; it does not create router mappings or provide TURN relay service. NAT hairpinning may be necessary for LAN clients using the public URL.
- Reverse proxies must preserve the original HTTP `Host`. Forwarded headers are deliberately not trusted. A CDN or HTTP-only tunnel address generally cannot receive the game's UDP traffic; use an explicit reachable `IP` override and appropriate UDP forwarding instead.
- DNS is resolved from the server's network, not the browser's. Split DNS, multiple DNS addresses, IPv6-only routing, and different internal/external ports may require an explicit override or network configuration. Automatic advertisement cannot guarantee connectivity through restrictive NAT/firewalls.

## Focused tests

The server module requires Go 1.25.1 or newer. `sfu.go` can be tested separately from the native engine entrypoint with:

```sh
cd vendor/server
GAME_DIR=cstrike CLIENT_WASM_PATH=test SERVER_WASM_PATH=test MENU_WASM_PATH=test \
EXTRAS_PATH=test FILESYSTEM_WASM_PATH=test DYNAMIC_LIBRARIES=test FILES_MAP=test \
go test -race ./src/server/sfu.go ./src/server/sfu_test.go
```

These tests cover URL authorities, explicit overrides, bounded DNS resolution/fallback, and independent concurrent API construction. They do not replace a browser connectivity test against the deployed UDP port.
