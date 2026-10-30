# syntax=docker/dockerfile:1
FROM ghcr.io/balintsoos/cs16-web-server@sha256:75a410e3406cbc525329df93216c740ca76d92d45b0da7e850ef762b4f106148 AS upstream
FROM python:3.12-alpine AS patch
COPY --from=upstream /xashds/xash /patched/xash
COPY --from=upstream /xashds/public/assets/index-D_oQDsUs.js /patched/public/assets/index-D_oQDsUs.js
COPY patch.py /tools/patch.py
RUN python3 -I /tools/patch.py /patched
FROM upstream
USER root
COPY --from=patch /patched/ /xashds/
COPY entrypoint.sh /usr/local/bin/portable-entrypoint
RUN chmod 755 /usr/local/bin/portable-entrypoint && mkdir -p /content/cstrike /xashds/public/cstrike && find /xashds/cstrike /xashds/public -type d -exec chown xashds {} +
ENV MAP=garten_v05 PORT=27018
EXPOSE 27016/tcp 27018/tcp 27018/udp
USER xashds
ENTRYPOINT ["/usr/local/bin/portable-entrypoint"]
CMD []
