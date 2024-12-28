# Mixmaster

Mixmaster is a lightweight build service that you self-host. It's a
replacement for something like Jenkins when your needs are minimal,
your hardware resources are modest, and your patience is limited.

Everything runs on-demand. Builds are initiated by HTTP requests
brokered by systemd.

## Installation

Mixmaster needs:

1. A Linux environment
2. [Raku](https://docs.raku.org) and some third-party libraries.
3. Whatever is used to build whatever you're building.

At the moment, the best option for installation is to clone the repository and run `make install`.

## Setup

First run `mixmaster setup` to establish a build root where builds will occur. It defaults to `~/Builds`.

The build root also houses the configuration file, `mixmaster.ini`.

Next run `mixmaster service` to install some systemd user services. These include:

- A systemd socket service listening on port 8585.
- A systemd path service.

Both of these commands are a starting point for further customization. The
configuration and service files are very much meant to be edited to taste.

## Architecture
Builds are kicked off by HTTP requests that arrive on port 8585. A web server acting as a reverse proxy is a nice option for this and would allow for HTTPS.

Something needs to initiate the build request. The primary use case right now involves webhooks sent from Gitea.

The systemd socket created during `mixmaster setup` invokes `mixmaster bridge` and pipes in the JSON body of the HTTP request, which is then dropped into the inbox directory within the build root.

The systemd path service watches the inbox and uses the JSON payload to kick off a build by checking out the appropriate repository and running the designated build command. Both of these are drawn from the configuration file.
The configuration file dictates what projects Mixmaster can build and how it goes about doing so.

A project consists of one or more key-value pairs. The key is the name
of a branch within the project repository (the "what" of the
build). The value is the command that Mixmaster should execute to
perform the build (the "how). For example:

```
[example-org/example-repo]
production = make deploy
staging = make deploy-to-staging
```

If a build request came in for the production branch of the
`example-org/example-repo` repository, Mixmaster would check out the
repository specified in the JSON payload and then run `make deploy`.

If the request was for the staging branch, it would instead run
`make deploy-to-staging`.

Branches are picked using simple matching. If Mixmaster was
asked to build a branch named `staging/my-feature` it would check out
that branch from the repository but still run `make deploy-to-staging`.

## Task Builds

If the JSON payload has a field named `task`, Mixmaster will use its
value to decide what build command to run. This can be useful for
ad-hoc jobs.

A task build is defined in the configruration by appending the target
branch with a slash:

```
[example-org/example-repo]
master/update-libraries = make update
master/docs = make docs
```

If the JSON payload contains `"target": "master"` and `"task":
"update-libraries"` then `make update`  will be run from
the master branch. If it has `"task": "docs"` then the master
branch will still be checked out, but `make docs` will be run instead.

In order for this to be useful, the build command needs to either
commit its changes back to the repository or publish them
somewhere. As with regular builds, the build command is the driver of what happens, not Mixmaster.

## Notifications

Mixmaster conveys build progress via email sent to the address
specified in the application config. A notification is sent when a job
is started, when it finishes, and when an error occurs.

To turn off these notifications, leave the value of `mailto`
in the application config blank.

## SSH Keys

When a build is started, `mixmaster` is invoked within an `ssh-agent`
session. This per-job instance that will be stopped when the build is
finished, and is separate from any other agent processes.

If the application config defines a value for `sshKey` it will be added
to the agent. This can be useful for jobs that interact with remote
servers.
