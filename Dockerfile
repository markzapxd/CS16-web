# syntax=docker/dockerfile:1
FROM debian:trixie-slim AS native
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 build-essential gcc-multilib g++-multilib pkg-config libbsd-dev:i386 libsdl2-dev:i386 libfreetype-dev:i386 libopus-dev:i386 libbz2-dev:i386 libvorbis-dev:i386 libopusfile-dev:i386 libogg-dev:i386 && rm -rf /var/lib/apt/lists/*
COPY build /tools
RUN sh /tools/checkout.sh https://github.com/FWGS/xash3d-fwgs.git d3bc7fabeea8586f38a501b4cc6233fa0545f5f0 /engine
RUN python3 -I /tools/patch-source.py engine /engine
WORKDIR /engine
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
RUN ./waf configure -T release -d --enable-openmp && ./waf build -j2

FROM golang:1.25.1-trixie AS server
RUN apt-get update && apt-get install -y --no-install-recommends gcc-multilib g++-multilib && rm -rf /var/lib/apt/lists/*
COPY build /tools
RUN sh /tools/checkout.sh https://github.com/jklenner/goxash3d-fwgs.git dd563e429ad3c4a0e96ad929b1e87911d7f94c6d /bindings
WORKDIR /server
COPY vendor/server/go.* ./
RUN go mod edit -replace github.com/yohimik/goxash3d-fwgs=/bindings && go mod download
COPY vendor/server/src/server ./src/server
COPY --from=native /engine/build/engine/libxash.a /bindings/pkg/libxash.a
COPY --from=native /engine/build/public/libbuild_vcs.a /bindings/pkg/libbuild_vcs.a
COPY --from=native /engine/build/public/libpublic.a /bindings/pkg/libpublic.a
COPY --from=native /engine/build/3rdparty/libbacktrace/libbacktrace.a /bindings/pkg/libbacktrace.a
COPY --from=native /engine/build/3rdparty/library_suffix/liblibrary_suffix.a /bindings/pkg/liblibrary_suffix.a
ENV GOARCH=386 CGO_ENABLED=1 CC="gcc -m32 -D__i386__" CGO_CFLAGS="-fopenmp -m32 -fno-ipa-cp" CGO_LDFLAGS="-fopenmp -m32"
RUN go build -trimpath -o /out/xash ./src/server

FROM emscripten/emsdk:4.0.23 AS web-engine
COPY build /tools
RUN sh /tools/checkout.sh https://github.com/FWGS/xash3d-fwgs.git f85aa0c8f7d46c27191132b44d872c8e331308de /engine
WORKDIR /engine
ENV EMCC_CFLAGS="-s USE_SDL=2"
RUN emconfigure ./waf configure --emscripten && emmake ./waf build -j2 && emmake ./waf install --destdir /out && mv /out/xash.js /out/raw.js

FROM emscripten/emsdk:4.0.17 AS game-client
COPY build /tools
RUN sh /tools/checkout.sh https://github.com/FWGS/cs16-client.git 2490c5e9b66928e86df191ec1cdd802b6357a71c /client
RUN emcmake cmake -S /client -B /build -DCMAKE_INSTALL_PREFIX=/out -DCMAKE_BUILD_TYPE=Release && cmake --build /build --target install -j2

FROM node:22-trixie-slim AS web
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
COPY vendor/engine-wrapper /wrapper
COPY --from=web-engine /out /wrapper/dist
WORKDIR /wrapper
RUN npm install --ignore-scripts && mkdir -p lib/generated && npm run build:ts
COPY vendor/server /web
COPY build /tools
RUN python3 -I /tools/patch-source.py client /web
WORKDIR /web
RUN npm pkg set 'devDependencies.xash3d-fwgs=file:/wrapper' && npm install --ignore-scripts && npm run build

# Game data remains external: no HLDS download or third-party game-server image.
FROM debian:trixie-slim AS final
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends libgcc-s1:i386 libstdc++6:i386 libgomp1:i386 ca-certificates && rm -rf /var/lib/apt/lists/* && groupadd xashds && useradd -m -g xashds xashds
WORKDIR /xashds
COPY --from=server /out/xash ./xash
COPY --from=native /engine/build/filesystem/filesystem_stdio.so ./filesystem_stdio.so
COPY --from=web /web/src/client/dist ./public
COPY --from=web-engine /out/filesystem_stdio.wasm ./public/filesystem_stdio.wasm
COPY --from=game-client /out/cstrike ./public/cstrike
COPY vendor/server/configs ./
COPY vendor/LICENSE.md /usr/share/doc/cs16-web/upstream-LICENSE.md
COPY entrypoint.sh /usr/local/bin/portable-entrypoint
RUN chmod 755 /usr/local/bin/portable-entrypoint && mkdir -p /content/cstrike /xashds/cstrike/maps /xashds/public/cstrike && chown -R xashds:xashds /xashds
ENV XASH3D_BASEDIR=/xashds LD_LIBRARY_PATH=/xashds MAP=garten_v05 PORT=27018 GAME_DIR=cstrike ENGINE_ARGS=-windowed,-game,cstrike ENGINE_CONSOLE="_vgui_menus 0" CLIENT_WASM_PATH=cstrike/cl_dlls/client_emscripten_wasm32.wasm SERVER_WASM_PATH=cstrike/dlls/cs_emscripten_wasm32.wasm MENU_WASM_PATH=cstrike/cl_dlls/menu_emscripten_wasm32.wasm EXTRAS_PATH=cstrike/extras.pk3 FILESYSTEM_WASM_PATH=filesystem_stdio.wasm DYNAMIC_LIBRARIES="dlls/cs_emscripten_wasm32.wasm,/rodir/filesystem_stdio.wasm" FILES_MAP="dlls/cs_emscripten_wasm32.wasm:cstrike/dlls/cs_emscripten_wasm32.wasm,/rodir/filesystem_stdio.wasm:filesystem_stdio.wasm"
EXPOSE 27016/tcp 27018/tcp 27018/udp
USER xashds
ENTRYPOINT ["/usr/local/bin/portable-entrypoint"]
CMD []
