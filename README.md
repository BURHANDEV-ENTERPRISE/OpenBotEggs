# OpenBotEggs

Pterodactyl egg for [OpenBot](https://github.com/nightly-labs/openbot) (self-hosted server).

- `OpenBot.json` — import into the panel (Admin › Nests › Import Egg).
- `Dockerfile`, `ptero-entry.sh` — the official image plus a Pterodactyl entry point, built to
  `ghcr.io/burhandev-enterprise/openbot-pterodactyl:latest` by `.github/workflows/build.yml` every 6 hours.

## Node requirement (once per node)

OpenBot's Electron sandbox needs user namespaces, which Docker's default seccomp profile refuses.
On the Wings node, as root:

```sh
curl -fsSL -o /etc/docker/seccomp-openbot.json https://raw.githubusercontent.com/nightly-labs/openbot/main/docker/seccomp.json
# add to /etc/docker/daemon.json:  "seccomp-profile": "/etc/docker/seccomp-openbot.json"
systemctl restart docker
```

This applies to every container on the node: it is Docker's default profile plus `clone`/`unshare`.

## Use

1. Start the server and wait for `[OpenBot] Ready.`
2. Type `login` in the console, then your OpenBot email and the code sent to it.
3. Use the server from the OpenBot app or https://openbot.run/app.

Console commands: `login`, `status`, `mobile-connect`, `name <name>`, `logout`, `version`.

OpenBot is licensed under PolyForm Noncommercial 1.0.0.
