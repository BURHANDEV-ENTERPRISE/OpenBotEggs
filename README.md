# OpenBotEggs

Pterodactyl egg for [OpenBot](https://github.com/nightly-labs/openbot) (self-hosted server).

- `OpenBot.json` — import into the panel (Admin › Nests › Import Egg).
- `Dockerfile`, `ptero-entry.sh` — the official image plus a Pterodactyl entry point, built to
  `ghcr.io/burhandev-enterprise/openbot-pterodactyl:latest` by `.github/workflows/build.yml` every 6 hours.

## Sandbox

Pterodactyl cannot give one server its own seccomp profile, and Docker's default profile refuses the
user namespaces that the Electron sandbox needs. So OpenBot runs with `--no-sandbox`, and the
container is the boundary: agents work inside it and cannot leave it. No change to the node is needed.

## Limits

Tools inside the container (free, nproc, df, /proc) show the whole host. At every start the server
prints its real CPU, memory and disk limits, which Wings writes from the plan into
, and puts them in the agents' instruction files
(, ) so agents stay within them.

## Use

1. Start the server and wait for `[OpenBot] Ready.`
2. Type `login` in the console, then your OpenBot email and the code sent to it.
3. Use the server from the OpenBot app or https://openbot.run/app.

Console commands (type `help` to list them): `help`, `login`, `status`, `mobile-connect`, `name <name>`, `logout`, `version`.

OpenBot is licensed under PolyForm Noncommercial 1.0.0.
