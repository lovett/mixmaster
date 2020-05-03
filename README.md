# Mixmaster

Mixmaster is a lightweight build service. It's a replacement for
Jenkins when your needs are minimal, your hardware resources are
modest, and your patience for elaborate build pipelines is limited.

Mixmaster is self-hosted and user-centric. It consists of 3 scripts, 2
systemd services, and 1 configuration file. Everything runs on-demand,
either from your own account as an extension of yourself, or from a
dedicated user with its own identity.

## Setup

Mixmaster needs:

1. A Linux environment with systemd
2. [Raku](https://docs.raku.org) and some third-party libraries.
3. Whatever software is used to build whatever you're building.

Libraries can be installed using `zef`, which is included in recent
Raku releases. Use `make setup` to perform this
task on the local machine with `sudo`.

Application files are installed in two places. The files in the `bin`
folder go into `/usr/local/bin`. The `lib` folder goes into
`/usr/local/share/mixmaster`. Use `make install` to do this on the
local machine with `sudo`. Undo with `make uninstall`.

Next run `mmsetup`. It taskes care of application configuration. It
will create:

- The directory where builds are stored, `~/Builds`
- The main configuration file, `~/.config/mixmaster.ini`
- A systemd socket user service listening on port 8585.
- A systemd path user service.

Run `mmsetup --help` for details on changing these defaults.

The setup script is just a convenience for getting started. Once it
has populated the configuration and systemd files, edit directly as
needed.

To undo the changes make by `mmsetup`, run `mmsetup --teardown`.

## Architecture
Builds are kicked off by HTTP requests with JSON payloads received by
a systemd user socket service.

The systemd socket service runs `mmbridge`, which translates the JSON into an
INI file that is written to a spool directory.

The systemd path service watches the spool directory and runs
`mmbuild`, which checks out the appropriate repository and executes
the build command indicated by the job file.

The configuration file `~/.config/mixmaster.ini` defines the projects
Mixmaster can build. Each section defines a project, and the default
section (`[_]`) defines application settings.

A project consists of one or more key-value pairs. The key is the name
of a branch within the project repository (the "what" of the
build). The value is the command that Mixmaster should execute to
perform the build (the "how). For example:

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

## Endpoints
Mixmaster's socket service accepts JSON payloads via HTTP POST
or PUT in one of two formats. Each format has its own endpoint.

The default endpoint is, `/` and accepts a "lightweight" payload:

```
{
  "scm": "git",
  "repositoryUrl": "git@git.example.com:example-org/example-repo.git",
  "project": "example-org/example-repo",
  "commit": "abc123",
  "target": "production",
  "viewUrl": "http://gitea.example.com"
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
Webhooks) whose Target URL is `http://mixmaster.example.com/gitea`,
HTTP Method is `POST`, POST Content Type is `application/json`, and
Trigger On is `Push Events`.

There's also a `/version` endpoint that will return the installed
version of the `mmbridge` script via GET. It can useful for verifying
the socket service is up and running.

## Endpoint Exposure

Mixmaster's external interface is the TCP port the socket service
listens on (by default, 8585). Sending requests directly to that port
may be enough by itself.

A fancier option involves proxying requests via a web server. This
allows for things like HTTPS, custom hostnames, and
authentication. For example, here's an Nginx-based virtual host:

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

## Task Builds

The default endpoint supports another kind of build: on-demand tasks
performed within a repository checkout. If the JSON payload has a
field named `task`, Mixmaster will use its value to decide what build
command to run.

In the application config, a task build is defined by appending the
target with a slash and the task name:

```
[example-org/example-repo]
master/update-libraries = make update
master/docs = make docs
```

If the JSON payload has `"target": "master"` and `"task":
"update-libraries"` then the `make update` command will be run from
the master branch. If it instead has `"task": "docs"` then the master
branch will still be checked out, but `make docs` will be run instead.

In order for this to be useful, the build command needs to either
commit its changes back to the repository or publish them
somewhere. As with regulard builds, what happens when the build
command runs is up to you.

## Notifications

Mixmaster conveys build progress via email sent to the address
specified in the application config. A notification is sent when a job
is started, when it finishes, and when an error occurs.

To turn off notifications for all builds, leave the value of `mailto`
in the application config blank. To turn off notifications on a
per-build basis, provide a `notifications` field in the JSON payload
set to `none`. This only works for the default endpoint.


## SSH Keys

When a build is started, the `mmbuild` script is wrapped in a call to
`ssh-agent`. This results in a per-job agent instance that will be
stopped when the build is finished, and is separate from any other
agent processes.

If the appliation config defines a value for `sshKey` it will be added
to the agent. This can be useful for jobs that interact with remote
servers.

If reusing a single key across all builds isn't desirable, other
setups could be handled on a build-by-build basis by incorporating a
call to `ssh-add` into the build process.

In all cases the SSH key would need to be passwordless.
