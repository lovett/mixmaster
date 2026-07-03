# Mixmaster

Mixmaster is a lightweight build service. It's a replacement for things like Jenkins and GitHub Actions when your needs are minimal and your hardware is modest.

It runs on-demand via systemd. Builds are triggered by HTTP requests.


## Architecture
Builds are kicked off by HTTP requests. A systemd socket service runs `mixmaster bridge` and transforms the request into a job file.

Job files are written to the filesystem and picked up by a systemd path service that runs `mixmaster build`.

Build commands are stored in a configuration file. Builds occur in a designated directory.


## Installation

Mixmaster needs:

1. A Linux environment
2. [Raku](https://docs.raku.org) and some third-party libraries.
3. Whatever is used to build whatever you're building.

To install:
  - Clone the repository
  - Run `scripts/install.sh`. The application installs to `$*HOME/.raku`.

If installation is successful, running `mixmaster --version` should work.

## Setup
Run `mixmaster setup` to establish a build root where builds will occur. The default location is `~/Builds`. Override with the `--buildroot` flag.

Next run `mixmaster service` (also with `--buildroot` if needed) to install systemd user services:
  - A socket service listening on port 8585 to receive build requests.
  - A path service to pick up jobs created by the socket service.

__Services are populated, but not enabled.__ To enable them:
```
systemctl --user enable --now mixmaster-bridge.socket
systemctl --user enable --now mixmaster.path
```

__Services should be customized.__ The path to the Raku executable might not be ideal. Edit the `ExecStart` lines in `mixmaster-bridge@.service` and `mixmaster.service` if they refer to a location that won't be long-term stable.

### External Access
The socket service is the application's HTTP entry point. If accessing directly, a firewall adjustment may be needed to allow access to port `8585`.

Reverse proxying through a web server is another option, in which case port `8585` can remain closed.

If you can run `curl http://localhost:8585/hello` and get back a response, it's working. If not, check the systemd journal for errors:

```
journalctl --user -g mixmaster-bridge --since today
```

### Webhooks
To connect Mixmaster to Forgejo or similar, set up a Webhook in that system:
  - URL: The the root URL (for example, `http://example.com:8585` or `https://mixmaster.example.com`)
  - HTTP Method: POST or PUT
  - Content Type: application/json
  - Trigger on: Push events
  - Branch filter: * (Mixmaster will ignore requests about unfamiliar branches)

### Projects
Each section of the configuration file (by default, `~/Builds/config.ini`) defines a project.

The section name is the repository in the typical "organization-name/repo-name" format.

Each entry within a section maps a branch name to a build command. For example:

```
[example-org/example-repo]
production = make deploy
staging = make deploy-to-staging
```

If a build request arrives for the `production` branch of the `example-org/example-repo` repository, Mixmaster should run `make deploy`.

For the staging branch, it should run `make deploy-to-staging`.

Branches are matched by prefix, so a `staging/my-feature` branch would run the build command for `staging`.


## Notifications
Build progress is conveyed via email sent to the address specified in the configuration file. Messages are sent when a job is started, when it finishes, and when an error occurs.

To turn off these notifications, leave the value of `mailto` in the application config blank.

## SSH Keys

Builds are invoked within a dedicated `ssh-agent` session that is per-job and separate from any other agent processes.

If the configuration file defines a value for `sshKey` it will be loaded into to the agent.
