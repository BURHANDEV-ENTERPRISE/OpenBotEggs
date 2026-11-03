# Official OpenBot image + Pterodactyl entry point. Rebuilt by .github/workflows/build.yml.
ARG OPENBOT_TAG=latest
FROM ghcr.io/nightly-labs/openbot:${OPENBOT_TAG}
USER root
# Wings runs the container as a UID with no passwd entry; dbus and the keyring need one.
RUN apt-get update \
  && apt-get install -y --no-install-recommends libnss-wrapper \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s "$(dpkg -L libnss-wrapper | grep '/libnss_wrapper\.so$' | head -n1)" /usr/local/lib/libnss_wrapper.so \
  && test -e /usr/local/lib/libnss_wrapper.so
# The CLI only knows /run/openbot/control.sock, a folder owned by UID 1000. Under Wings the socket is in
# XDG_RUNTIME_DIR, so the CLI reads it from there.
RUN cli=/opt/OpenBot/app/resources/hosting/openbot   && sed -i 's|^SOCKET=/run/openbot/control.sock$|SOCKET=${OPENBOT_CONTROL_SOCKET:-/run/openbot/control.sock}|' "$cli"   && grep -q 'OPENBOT_CONTROL_SOCKET' "$cli"
COPY --chmod=0755 ptero-entry.sh /usr/local/bin/ptero-entry
ENV HOME=/home/container
WORKDIR /home/container
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ptero-entry"]
