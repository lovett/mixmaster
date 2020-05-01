# Mixmaster

Mixmaster is a build service for small-scale needs. It's a replacement
for Jenkins.

Mixmaster is geared towards self-hosted, user-centric use: either from
a dedicated user account or as something you run under your own
account.

It consists of 2 systemd services. One listens for build requests over
HTTP. The other performs the build.

## Setup

Mixmaster needs:

1. A Linux environment with systemd
2. A [Raku](https://docs.raku.org) installation
3. A few third-party Raku libraries

The Raku libraries can be installed using `zef`, which is
included in recent Raku releases. Use `make setup` to perform this
task on the local machine. It uses sudo so that the packages
are available system-wide.

Application files are installed in two places. The files in the `bin`
folder go into `/usr/local/bin`. The `lib` folder goes into
`/usr/local/share/mixmaster`. Use `make install` to do this on the
local machine with `sudo`. Use `make uninstall` to undo.

The `mmsetup` script takes care of application-specific
configuration. It will create:

- The directory where builds are stored, `~/Builds`
- The main configuration file, `~/.config/mixmaster.ini`
- A systemd socket user service listening on port 8585.
- A systemd path user service.

Run `mmsetup --help` for details on changing these defaults.

The setup script is just a convenience for getting started. Once it
has populated the configuration and systemd files, they should be
directly edited as needed.

## Architecture
Builds are kicked off by HTTP requests that are received by a systemd
user socket service. The HTTP request consists of a JSON payload.

The socket service runs `mmbridge`, which translates the JSON into an
INI file that is written to a spool directory.

The path service watches the spool directory and runs `mmbuild`, which
handles repository checkout and executing build commands.

The configuration file `~/.config/mixmaster.ini` defines the projects
Mixmaster can build. Each section defines a project, and the default
section (`[_]`) defines application settings.

A project consists of one or more property-and-value pairs. The
property is either the name of a branch within the project repository
or some meaningful keyword. The value is the command that Mixmaster
should execute to perform the build. For example:

```
[example-org/example-repo]
production = make deploy
staging = make deploy-to-staging
```

If a build request comes in for the production branch of the
`example-org/example-repo` repository, Mixmaster will check out the
repository and then run `make deploy`. If the request is for the
staging branch, it will run `make deploy-to-staging` instead.

Branches are picked based on starts-with matching. If Mixmaster was
asked to build a branch named `staging/my-feature` it would check out
that branch from the repository but still run `make deploy-to-staging`.

The project definitions in the configuration file are only a mapping
between targets (the "what" of the build) and commands (the
"how").

## Endpoints
Mixmaster's socket service accepts JSON payloads via HTTP POST
or PUT in one of three formats. Each format has its own endpoint.

The default endpoint is, `/` and accepts a "lightweight" payload:

```
{
  "scm": "git",
  "repositoryUrl": "git@git.example.com:example-org/example-repo.git",
  "project": "example-org/example-repo",
  "commit": "abc123",
  "target": "production",
  "viewUrl": "http://example.com"
}
```

These parameters tell Mixmaster where to find the project repository,
how to interact with it (i.e. that it's a Git repository), and which
branch and commit to check out. The `viewUrl` field is useful for
linking back to the issue or pull request that the build was initiated
from.

The `/gitea` endpoint works the same way but accommodates the more
verbose payload that Gitea sends for webhooks. For each participating
repository hosted on Gitea, you'd have a webhook (under Settings ->
Webhooks) whose Target URL is `http://example.com/gitea`, HTTP Method
is `POST`, POST Content Type is `application/json`, and Trigger On is
`Push Events`.

## Other Endpoints

`GET /version` will display the installed version of the `mmbridge`
script. This is useful for verifying the socket service is up and
running.

## Endpoint Exposure

Mixmaster's external interface is the TCP port the socket service
listens on (by default, 8585). Sending requests directly to that port
may be enough by itself.

A fancier option involves proxying requests via a web server. This
allows for things like, custom hostnames, and authentication. As an
example, here's what an Nginx-based virtual host could look like:

```
server {
    listen 80;
    listen [::]:80;
    server_name mixmaster.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mixmaster.example.com;
    ssl_certificate /path/to/ssl/certificate
    ssl_certificate_key /path/to/ssl/key

    location / {
        proxy_pass http://127.0.0.1:8585;
        proxy_redirect off;
        gzip off;
        include /etc/nginx/proxy_params;
    }
}
```

## SSK Keys

When a build is started, the `mmbuild` script is wrapped in a call to
`ssh-agent`. This results in a per-job agent instance that will be
stopped when the build is finished, and is separate from any other
agent processes.

If the main configuration file (`~/.config/mixmaster.ini`) defines a
value for `sshKey` it will be added to the agent. This can be useful
for jobs that interact with remote servers.

If reusing a single key across all builds isn't desirable, other
setups could be handled on a build-by-build basis by incorporating a
call to `ssh-add` into the build process. In all cases the SSH key
would need to be passwordless.
