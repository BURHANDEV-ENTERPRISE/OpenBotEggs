# Official OpenBot image + Pterodactyl entry point. Rebuilt by .github/workflows/build.yml.
ARG OPENBOT_TAG=latest
FROM ghcr.io/nightly-labs/openbot:${OPENBOT_TAG}
USER root
COPY --chmod=0755 ptero-entry.sh /usr/local/bin/ptero-entry
ENV HOME=/home/container
WORKDIR /home/container
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ptero-entry"]
