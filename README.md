# docker-openresty - Docker tooling for OpenResty

[![Build Status](https://github.com/openresty/docker-openresty/actions/workflows/docker-publish.yml/badge.svg?branch=master)](https://github.com/openresty/docker-openresty/actions/workflows/docker-publish.yml)  [![](https://images.microbadger.com/badges/image/openresty/openresty.svg)](https://microbadger.com/#/images/openresty/openresty "microbadger.com")

`docker-openresty` is [Docker](https://www.docker.com) tooling for [OpenResty](https://www.openresty.org).

Docker is a container management platform. OpenResty is a full-fledged web application server by
bundling the standard nginx core, lots of 3rd-party nginx modules, as well as most of their external dependencies.

Thank you to [Travis CI](https://www.travis-ci.com) for donating their build infrastructure to this project for over seven years!  We have since migrated to [GitHub Actions](https://github.com/openresty/docker-openresty/actions).

We provide a series of [pre-built images](#openresty-image-tags) for various operating systems. Some are built-from the upstream OpenResty pre-built images and some are built from source.

You can learn more about building your own custom and derived images in [`BUILDING.md`](./BUILDING.md).   You can learn more about securing your operations in [`HARDENING.md`](./HARDENING.md).

----

Table of Contents
=================

* [Table of Contents](#table-of-contents)
* [OpenResty Image Tags](#openresty-image-tags)
* [Image Mirror](#image-mirror)
* [Usage](#usage)
* [Policies](#policies)
* [Nginx Config Files](#nginx-config-files)
* [Running as Non-Root](#running-as-non-root)
* [Docker Entrypoint](#docker-entrypoint)
* [OPM](#opm)
* [LuaRocks](#luarocks)
* [Tips & Pitfalls](#tips--pitfalls)
* [Image Labels](#image-labels)
* [Docker CMD](#docker-cmd)
* [Feedback & Bug Reports](#feedback--bug-reports)
* [Changelog & Authors](#changelog--authors)
* [Copyright & License](#copyright--license)

----

# OpenResty Image Tags

It is best practice to pin your images to an explicit image tag.  The [next section](#supported-tags-and-respective-dockerfile-links) below covers the conventions in detail, but here are some common examples:

| Image  | Description |
| --- | --- |
| `openresty/openresty:1.29.2.4-1-resolute` | Built-from-source Ubuntu Resolute Raccoon |
| `openresty/openresty:1.29.2.4-1-noble` | Built-from-source Ubuntu Noble Narwhal |
| `openresty/openresty:1.29.2.4-1-jammy` | Built-from-source Ubuntu Jammy Jellyfish |
| `openresty/openresty:1.29.2.4-1-bookworm-fat` | Built-from-upstream Debian Bookworm |
| `openresty/openresty:1.29.2.4-1-alpine` | Built-from-source Alpine |
| `openresty/openresty:1.29.2.4-1-alpine-apk` | Built-from-upstream Alpine |
| `openresty/openresty:1.31.1.1-1-restyrepo` | Built-from-source OpenResty GitHub branch on Debian Trixie |
| `openresty/openresty:1.31-alpine` | Latest Alpine image in the OpenResty 1.31 release series |

These are examples of untagged image names, for reference:

| Image | Description |
| --- | --- |
| `openresty/openresty:resolute` | Latest Ubuntu Resolute |
| `openresty/openresty:noble` | Latest Ubuntu Noble |
| `openresty/openresty:jammy` | Latest Ubuntu Jammy |
| `openresty/openresty:alpine` | Latest Alpine |
| `openresty/openresty:restyrepo` | Latest OpenResty GitHub source branch build |

There are also specific tags for [Debug](https://openresty.org/en/deb-packages.html#openresty-debug) and [Valgrind](https://openresty.org/en/deb-packages.html#openresty-valgrind) OpenResty variants:
| Image | Description |
| --- | --- |
| `openresty/openresty:bookworm-debug` | Bookworm flavor with `openresty-debug` |
| `openresty/openresty:bookworm-valgrind` | Bookworm flavor with `openresty-valgrind` |

## Image Registries
 
 The CI/CD pipeline builds images to the [GitHub Container Registry](https://github.com/openresty/docker-openresty/pkgs/container/openresty) (GHCR) as the primary source.
 
 * `ghcr.io/neomantra/openresty`
 
 The images are then mirrored to [Docker Hub](https://hub.docker.com/r/openresty/openresty/) for convenience and backward compatibility.
 
 * `openresty/openresty` (or `docker.io/openresty/openresty`)


----

Usage
=====

If you are happy with the build defaults, then you can use the openresty image from the [Docker Hub](https://hub.docker.com/r/openresty/openresty/).  The image tags available there are listed at the top of this README.

```
docker run [options] openresty/openresty:bookworm-fat
```

*[options]* would be things like -p to map ports, -v to map volumes, and -d to daemonize.

`docker-openresty` symlinks `/usr/local/openresty/nginx/logs/access.log` and `error.log` to `/dev/stdout` and `/dev/stderr` respectively, so that Docker logging works correctly.  If you change the log paths in your `nginx.conf`, you should symlink those paths as well. This is not possible with the `windows` image.

⚠️ Do **not** bind-mount a host directory over `/usr/local/openresty/nginx/logs`: the mount shadows those symlinks, so logging silently goes to regular files inside the mount and nothing appears in `docker logs` ([#91](https://github.com/openresty/docker-openresty/issues/91)).  Mounting a *named volume* there with Docker's default copy behavior is harmless because Docker copies the image's symlinks into an empty named volume on first use; named volumes mounted with the `nocopy` option have the same problem as bind mounts.  The [entrypoint](#docker-entrypoint) warns at startup when these paths are not symlinks; if logging to files is what you want, silence it with `NGINX_ENTRYPOINT_QUIET_LOGS=1`.

Linux images place the `*_temp_path` temporary directories under `/var/run/openresty/`. Only the optional `-entrypoint` variants also relocate the PID there and make that directory mode `1777`. Standard flavors retain their compiled-in PID location. See [Running as Non-Root](#running-as-non-root) for the appropriate writable mounts and PID settings.

Supported tags and respective `Dockerfile` links
=========

The following "flavors" are available and built from [upstream OpenResty packages](https://openresty.org/en/linux-packages.html):

- [`alpine-apk`, (*alpine-apk/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/alpine-apk/Dockerfile)
- [`bookworm-buildpack`, (*bookworm/Dockerfile.buildpack*)](https://github.com/openresty/docker-openresty/blob/master/bookworm/Dockerfile.buildpack)
- [`bookworm-debug`, (*bookworm/Dockerfile.debug*)](https://github.com/openresty/docker-openresty/blob/master/bookworm/Dockerfile.debug)
- [`bookworm-fat`, (*bookworm/Dockerfile.fat*)](https://github.com/openresty/docker-openresty/blob/master/bookworm/Dockerfile.fat)
- [`bookworm-valgrind`, (*bookworm/Dockerfile.valgrind*)](https://github.com/openresty/docker-openresty/blob/master/bookworm/Dockerfile.valgrind)
- [`bookworm`, (*bookworm/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/bookworm/Dockerfile)
- [`fedora`, `fedora-rpm`, (*fedora/Dockerfile* with `fc36`)](https://github.com/openresty/docker-openresty/blob/master/fedora/Dockerfile)
- [`rocky`, (*fedora/Dockerfile* with `rockylinux`)](https://github.com/openresty/docker-openresty/blob/master/fedora/Dockerfile)
- [`windows`, (*windows/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/windows/Dockerfile)

The following "flavors" are built from source and are intended for more advanced and custom usage, caveat emptor:

- [`alma`, (*alma/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/alma/Dockerfile)
- [`alpine-fat`, (*alpine/Dockerfile.fat*)](https://github.com/openresty/docker-openresty/blob/master/alpine/Dockerfile.fat)
- [`alpine`, (*alpine/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/alpine/Dockerfile)
- [`alpine-slim`, (*alpine/Dockerfile*](https://github.com/openresty/docker-openresty/blob/master/alpine/Dockerfile), stripped Alpine image)
- [`jammy`, (*jammy/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/jammy/Dockerfile)
- [`noble`, (*noble/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/noble/Dockerfile)
- [`restyrepo`, (*restyrepo/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/restyrepo/Dockerfile)

The `openresty/openresty:latest` tag points to the latest `bookworm` image.

Since `1.19.3.2-1`, all flavors support multi-architecture builds, both `amd64` and `aarch64`.  Since `1.21.4.1-1`, the `s390x` architecture is supported for build-from-source Ubuntu flavors (like `jammy`); prior to version `1.27.1.2-3`, [PCRE JIT](https://github.com/zherczeg/sljit/issues/89) is disabled for `s390x`.

Starting with `1.13.6.1`, releases are tagged with `<openresty-version>-<image-version>-<flavor>`.  The latest `image-version` will also be tagged `<openresty-version>-<flavor>`.  OpenResty release series are also tagged as `<openresty-major>.<openresty-minor>-<flavor>`, such as `1.31-alpine`.  The HEAD of the master branch is also labeled plainly as `<flavor>`.  The builds are managed by [GitHub Actions](https://github.com/openresty/docker-openresty/actions).

There are architecture-specific tags as well, `<openresty-version>-<image-version>-<flavor>-<arch>` and `<openresty-major>.<openresty-minor>-<flavor>-<arch>`, but one would generally pull from the multi-architecture name above.

OpenResty supports SSE 4.2 optimizations.  Starting with the `1.19.3.1` series, the architecture is auto-detected and the optimizations enabled accordingly.  Earlier image series `1.15.8.1` and `1.17.8.2` have `-nosse42` image flavors for systems which explicitly disable SSE 4.2 support; this is useful for older systems and embedded systems.  They are built with `-mno-sse4.2` appended to the build arg `RESTY_LUAJIT_OPTIONS`.  It is highly recommended *NOT* to use these if your system supports SSE 4.2 because the `CRC32` instruction dramatically improves large string performance.  These are only for built-from-source flavors, e.g. `1.15.8.1-3-bionic-nosse42`, `1.15.8.1-3-alpine-nosse42`, `1.15.8.1-3-alpine-fat-nosse42`.

It is *highly recommended* that you use the upstream-based images for best support.  For best stability, pin your images to the full tag, for example `1.21.4.1-0-bionic`.

The `restyrepo` flavor is a built-from-source image that clones the OpenResty GitHub repository, builds the OpenResty source tarball from the selected branch or tag, and then builds OpenResty from that generated tarball.  It uses Debian Trixie as its base image and is published for `amd64` and `arm64`.

`-fat` images are ones that have [LuaRocks and OPM](#opm) installed in them. `-buildpack` images are based on [`buildpack-deps` images](https://hub.docker.com/_/buildpack-deps#what-is-buildpack-deps); they might be useful when more build scaffolding is required in your application.


Policies
========

The [Maintainers](#changelog--authors) of this OpenResty Docker Tooling operate under the following policies:

 * We track [OpenResty releases](https://openresty.org/en/linux-packages.html) for build-from-upstream and will continue to add new upstream releases:

    * [`alpine-apk`, (*alpine-apk/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/alpine-apk/Dockerfile)
    * [`amzn2`, (*centos/Dockerfile* with `amzn2`)](https://github.com/openresty/docker-openresty/blob/master/centos/Dockerfile)
    * [`centos`, `centos-rpm`, (*centos/Dockerfile* with `el8`)](https://github.com/openresty/docker-openresty/blob/master/centos/Dockerfile)
    * [`centos7`, (*centos7/Dockerfile* with `el7`)](https://github.com/openresty/docker-openresty/blob/master/centos7/Dockerfile)
    * [`fedora`, `fedora-rpm`, (*fedora/Dockerfile* with `fc36`)](https://github.com/openresty/docker-openresty/blob/master/fedora/Dockerfile)
    * [`rocky`, (*fedora/Dockerfile* with `rockylinux`)](https://github.com/openresty/docker-openresty/blob/master/fedora/Dockerfile)
    * [`windows`, (*windows/Dockerfile*)](https://github.com/openresty/docker-openresty/blob/master/windows/Dockerfile)

 * We track build-from-source images as follows:
 
    * [Alma Linux latest stable](https://almalinux.org/get-almalinux/)
    * [Alpine `stable`](https://www.alpinelinux.org/releases/)
    * [Ubuntu "LTS"](https://wiki.ubuntu.com/Releases)

 * We try to include popular architectures (`x86_64`, `aarch64`, `s390x`)

 * RC versions of upstream releases will be made available on tags

 * If an image fails CI/CD too much, we will remove it.

 * We operate in English and PRs must be English as well, unless for localization purposes.
 
 * We will accept issues in any language.  We will provide our translations to English for clarity.

 * All are welcome to particpate, but must show mutual respect to the community.

Nginx Config Files
==================

The Docker tooling installs its own [`nginx.conf` file](https://github.com/openresty/docker-openresty/blob/master/nginx.conf).  If you want to directly override it, you can replace it in your own Dockerfile or via volume bind-mounting.

For the Linux images, that `nginx.conf` has the directive `include /etc/nginx/conf.d/*.conf;` so all nginx configurations in that directory will be included.  The [default virtual host configuration](https://github.com/openresty/docker-openresty/blob/master/nginx.vh.default.conf) has the original OpenResty configuration and is copied to `/etc/nginx/conf.d/default.conf`.

Since `1.25.3.2-2`, the `nginx.conf` also contains `include /etc/nginx/conf.d/*.main;` at the `main` stanza level (rather than the `http` level of `*.conf`).   `stream` and other `main` level directives can be included there; see [issue 257](https://github.com/openresty/docker-openresty/issues/257) for an example.

You can override that `default.conf` directly or volume bind-mount the `/etc/nginx/conf.d` directory to your own set of configurations:

```
docker run -v /my/custom/conf.d:/etc/nginx/conf.d openresty/openresty:alpine
```

If you are running on an `selinux` host (e.g. CentOS), you may need to add `:Z` to your [volume bind-mount argument](https://docs.docker.com/storage/bind-mounts/#configure-the-selinux-label):
```
docker run -v /my/custom/conf.d:/etc/nginx/conf.d:Z openresty/openresty:alpine
```

When using the `windows` image you can change the main configuration directly:
```
docker run -v C:/my/custom/nginx.conf:C:/openresty/conf/nginx.conf openresty/openresty:windows
```


Running as Non-Root
===================

The optional `-entrypoint` images support arbitrary non-root UIDs ([#119](https://github.com/openresty/docker-openresty/issues/119)). Standard flavors retain their existing PID path and permissions; use the complete example in [HARDENING.md](HARDENING.md#run-as-non-root-with-a-read-only-filesystem) for those images.

For an entrypoint variant:

```
docker run --user 1000:1000 openresty/openresty:bookworm-entrypoint
```

In `-entrypoint` images, all default runtime-writable paths live under `/var/run/openresty`, which has `/tmp`-style permissions (mode `1777`):

 * the `*_temp_path` directories (`client_body`, `proxy`, `fastcgi`, `uwsgi`, `scgi`)
 * the PID file `/var/run/openresty/nginx.pid`

Access and error logs are symlinked to `/dev/stdout` and `/dev/stderr`, so nothing else needs to be writable.  If you replace the stock [`nginx.conf`](#nginx-config-files), keep its `pid` and `*_temp_path` directives pointing at a writable location.

The [default virtual host](https://github.com/openresty/docker-openresty/blob/master/nginx.vh.default.conf) listens on port 80. Docker normally allows non-root processes to bind low ports inside containers. On runtimes that enforce privileged ports, change `listen` to an unprivileged port such as `8080`, or set `net.ipv4.ip_unprivileged_port_start` as in the Kubernetes example below. See [Kubernetes sysctl documentation](https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster/#safe-and-unsafe-sysctls).

With a read-only root filesystem (`docker run --read-only` or Kubernetes `readOnlyRootFilesystem: true`), mount a writable `tmpfs` / `emptyDir` at `/var/run/openresty`:

```
docker run --user 1000:1000 --read-only --cap-drop=ALL \
  --security-opt no-new-privileges=true \
  --tmpfs /var/run/openresty:rw,noexec,nosuid,nodev,size=64m,mode=0700,uid=1000,gid=1000 \
  openresty/openresty:bookworm-entrypoint
```

```yaml
# Kubernetes
spec:
  securityContext:
    fsGroup: 1000
    sysctls:
      # allow nginx to bind port 80 as a non-root user
      - name: net.ipv4.ip_unprivileged_port_start
        value: "0"
  containers:
    - name: openresty
      image: openresty/openresty:bookworm-entrypoint
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ALL]
      volumeMounts:
        - name: openresty-run
          mountPath: /var/run/openresty
  volumes:
    - name: openresty-run
      emptyDir:
        medium: Memory
        sizeLimit: 64Mi
```

Mount the `tmpfs` at `/var/run/openresty` itself, not at `/var/run` — nginx creates its temporary directories inside `/var/run/openresty`, but does not recreate that directory when a mount hides it.  Use an ephemeral mount (`tmpfs` / `emptyDir`), not a persistent volume: files left behind by a run under a different UID (a stale root-owned `nginx.pid`, `0700` temp directories) block later non-root startups, and a mounted directory's own permissions replace the image's `1777`.

The 64 MiB limit is shared by request-body temporary files and proxy buffering spills; size it for your workload. The image's `1777` directory permits any container process to create entries, so prefer a mount owned by a fixed UID/GID when practical. Mode `0700` works in the Docker example because master and workers use the same UID.

If you use [configuration templates](#docker-entrypoint), the entrypoint renders them into `/etc/nginx/conf.d`, which is root-owned. Non-root runs must make the output directory writable using a derived image or a suitably owned volume. An unwritable output directory causes startup to fail. Mounting an empty volume there hides the stock `default.conf`, so templates must supply the entire server configuration. Stream templates also need writable `/etc/nginx/stream-conf.d` and `/etc/nginx/conf.d` directories.

See [HARDENING.md](HARDENING.md) for broader container-hardening guidance.


Docker Entrypoint
=================

Append `-entrypoint` to any published Linux flavor to opt into an Nginx-style startup layer: for example, `bookworm-entrypoint`, `alpine-slim-entrypoint`, `bookworm-fat-entrypoint`, or `bookworm-debug-entrypoint`. These are derived images built with [entrypoint/Dockerfile](entrypoint/Dockerfile). Existing flavors and `latest` retain their original startup behavior, configuration, and directory permissions. Windows and archived flavors have no entrypoint variants.

Each derived image uses the exact base digest built by the same CI job, inherits its architecture and installed OpenResty binaries, and adds `envsubst` when missing. The layer installs [`docker-entrypoint.sh`](docker-entrypoint.sh), startup hooks, and the non-root PID/directory changes described above. It does not rebuild OpenResty.

Tags follow the existing version scheme: `<version>-bookworm-entrypoint`, `1.31-bookworm-entrypoint`, and architecture-specific tags such as `bookworm-entrypoint-arm64`. Each variant has the same architectures as its base; `fedora-entrypoint` is amd64-only. See [BUILDING.md](BUILDING.md#building-entrypoint-variants) to build locally.

When the container's command is `openresty` or `nginx` (or their `-debug`/`-valgrind` variants — matched by basename, so full paths like `/usr/bin/openresty` work too), the entrypoint first executes any executable `*.sh` scripts in `/docker-entrypoint.d/` in sorted order, sourcing `*.envsh` files along the way, and then `exec`s the command.  Any other command (`resty`, `luajit`, `sh`, ...) is `exec`ed directly, skipping those scripts, so this image can still be used to invoke its other binaries.  Set `NGINX_ENTRYPOINT_QUIET_LOGS=1` to suppress the entrypoint's log output.

When switching from a standard flavor to `-entrypoint`, review mounts at `/docker-entrypoint.d` and `/etc/nginx/templates`: they become active at startup. Only mount trusted scripts. The PID also moves to `/var/run/openresty/nginx.pid`. Overriding `ENTRYPOINT` skips hooks but does not undo the derived layer's PID configuration or directory permissions; select the standard flavor to retain all original defaults.

⚠️ Binding a volume over the entire `/docker-entrypoint.d` directory **replaces** the stock contents of that directory (the scripts listed below, e.g. [`20-envsubst-on-templates.sh`](https://github.com/openresty/docker-openresty/blob/master/docker-entrypoint.d/20-envsubst-on-templates.sh)).  If you still want template rendering, include that script in your mount (or copy it into your image) alongside your own scripts.  Prefer adding individual files under that path, or `COPY` scripts into a derived image, rather than shadowing the whole directory.

Log Symlink Check
-----------------

The stock script [`10-check-log-symlinks.sh`](https://github.com/openresty/docker-openresty/blob/master/docker-entrypoint.d/10-check-log-symlinks.sh) warns on startup when `access.log` or `error.log` in the image's log directory is not a symlink.  That directory is read from the `RESTY_LOG_DIR` environment variable, which defaults to `/usr/local/openresty/nginx/logs`; the debug and valgrind images set it to their flavor-specific prefix, and derived images with custom log locations can set it likewise.  The image ships the log paths as symlinks to `/dev/stdout` and `/dev/stderr` so that logs reach `docker logs`; bind-mounting a volume over the logs directory shadows the symlinks and silently redirects logging into regular files (see [Usage](#usage) and issue [#91](https://github.com/openresty/docker-openresty/issues/91)).  The warning is written to stderr; set `NGINX_ENTRYPOINT_QUIET_LOGS=1` to suppress it if logging to files is intentional.

Custom Entrypoint Scripts
-------------------------

To run your own init logic when OpenResty starts, add an executable `*.sh` (or `*.envsh` to source) under `/docker-entrypoint.d/`.  Files run in version-sort order (`sort -V`), so numeric prefixes control ordering relative to the stock `10-check-log-symlinks.sh` and `20-envsubst-on-templates.sh`:

```
# In a derived Dockerfile
COPY 40-my-init.sh /docker-entrypoint.d/40-my-init.sh
RUN chmod +x /docker-entrypoint.d/40-my-init.sh
```

Or at runtime with a file mount (this does not hide the stock scripts):

```
docker run -v "$PWD/40-my-init.sh:/docker-entrypoint.d/40-my-init.sh:ro" openresty/openresty:bookworm-entrypoint
```

Flag Convenience and `RESTY_ENTRYPOINT_COMMAND`
-----------------------------------------------

If the first argument is a flag, the entrypoint prepends `RESTY_ENTRYPOINT_COMMAND`. This defaults to `openresty`; `bookworm-debug-entrypoint` and `bookworm-valgrind-entrypoint` select `openresty-debug` and `openresty-valgrind`, respectively. Their log and document-root paths also use the matching variant prefix. The default `CMD` is `["-g", "daemon off;"]`. Supplying your own arguments replaces those flags, so include `daemon off;` when starting a server:

```
docker run openresty/openresty:bookworm-entrypoint -g "daemon off; env FOO;"
```

Derivative images that change the server binary can set:

```
ENV RESTY_ENTRYPOINT_COMMAND="openresty-debug"
```

`bookworm-valgrind-entrypoint` remains a diagnostic image, not a production server. On ARM64, its Lua VM can fail to initialize outside Valgrind, including in the unchanged standard image. To run it under instrumentation, explicitly run startup hooks/configuration validation before Valgrind (a `sh` or `valgrind` command otherwise bypasses hooks):

```sh
docker run --rm openresty/openresty:bookworm-valgrind-entrypoint sh -ec '
  /docker-entrypoint.sh -t
  export TMPDIR=/var/run/openresty
  exec valgrind --tool=memcheck openresty-valgrind -g "daemon off; master_process off;"
'
```

`TMPDIR` keeps Valgrind's temporary files on the runtime mount when using a read-only root filesystem. See OpenResty's [Valgrind debugging guidance](https://openresty.org/en/debugging.html).

Environment Variables in Nginx Configuration
--------------------------------------------

The stock script [`20-envsubst-on-templates.sh`](https://github.com/openresty/docker-openresty/blob/master/docker-entrypoint.d/20-envsubst-on-templates.sh) templates environment variables into nginx configuration, [like the official Nginx image does](https://github.com/docker-library/docs/tree/master/nginx#using-environment-variables-in-nginx-configuration-new-in-119).  It reads template files from `/etc/nginx/templates/*.template` and writes the results of `envsubst` to `/etc/nginx/conf.d`, which the default `nginx.conf` includes.  It does nothing if `/etc/nginx/templates` does not exist; note that when it does, `/etc/nginx/conf.d` must be writable at startup.

For example, with a file `/etc/nginx/templates/default.conf.template` containing:

```
server {
    listen ${NGINX_PORT};
    ...
}
```

and running with `-e NGINX_PORT=8080`, the entrypoint writes `/etc/nginx/conf.d/default.conf` with `listen 8080;`.

For compatibility with the Nginx image, the same environment variables control its behavior:

 * `NGINX_ENVSUBST_TEMPLATE_DIR` — template directory (default: `/etc/nginx/templates`)
 * `NGINX_ENVSUBST_TEMPLATE_SUFFIX` — template file suffix (default: `.template`)
 * `NGINX_ENVSUBST_OUTPUT_DIR` — output directory (default: `/etc/nginx/conf.d`)
 * `NGINX_ENVSUBST_FILTER` — regex to restrict which environment variables are substituted (default: none, all variables)
 * `NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX` — stream template file suffix (default: `.stream-template`)
 * `NGINX_ENVSUBST_STREAM_OUTPUT_DIR` — stream output directory (default: `/etc/nginx/stream-conf.d`)

Stream templates (`*.stream-template`) are rendered into `/etc/nginx/stream-conf.d`.  Instead of appending a `stream` block to `nginx.conf` like the Nginx image does, the script writes `/etc/nginx/conf.d/stream.main`, which the default `nginx.conf` picks up via its `include /etc/nginx/conf.d/*.main;` directive (see [Nginx Config Files](#nginx-config-files)).

If a stream block already exists in a `*.main` file, include the stream output directory there. If `stream.main` exists without an active stream block, startup fails instead of overwriting it. Executable `.envsh` hooks are sourced in the entrypoint shell, and exported variables are available to later hooks and the final command. Failed hooks stop startup.


OPM
===

Starting at version 1.11.2.2, OpenResty for Linux includes a [package manager called `opm`](https://github.com/openresty/opm#readme), which can be found at `/usr/local/openresty/bin/opm`.

`opm` is built in all the images except `alpine` and `bookworm`.

To use `opm` in the `alpine` image, you must also install the `curl` and `perl` packages; they are not included by default because they double the image size.  You may install them like so: `apk add --no-cache curl perl`.

To use `opm` within the `bookworm` image, you can either use the `bookworm-fat` image or install the `openresty-opm` package in a custom build (which you would need to do to install your own `opm` packages anyway), as shown in [this buster example](https://github.com/openresty/docker-openresty/blob/master/archive/buster/Dockerfile.opm_example).


LuaRocks
========

[LuaRocks](https://luarocks.org/) is included in the `alpine-fat`, `centos`, and `bionic` variants.  It is excluded from `alpine` because it generally requires a build system and we want to keep that variant lean.

It is available at `/usr/local/openresty/luajit/bin/luarocks`.  Packages can be added in your dependent Dockerfiles like so:

```
RUN /usr/local/openresty/luajit/bin/luarocks install <rock>
```


Tips & Pitfalls
===============

 * All `-entrypoint` variants include `envsubst` for configuration templates. Availability in
 standard flavors depends on their Dockerfile. See [Docker Entrypoint](#docker-entrypoint).

 * By default, OpenResty is built with SSE4.2 optimizations if the build machine supports it.  If run on machine without SSE4.2, there will be [invalid opcode issues](https://github.com/openresty/docker-openresty/issues/39). **Thus all the Docker Hub images require SSE4.2.**  You can [build a custom image from source](BUILDING.md#building-from-source) explicitly without SSE4.2 support, using build arguments like so:
```
docker build -f bionic/Dockerfile --build-arg "RESTY_LUAJIT_OPTIONS=--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT -mno-sse4.2'" .
```

* OpenResty's OpenSSL library version must be compatible with your `opm` and LuaRocks packages' version.  At minimum, the numeric portion should be the same (e.g. `1.1.1`).  The image label `resty_openssl_version` indicates this value. see [Labels](#image-labels).

* The `1.13.6.2-alpine` is built from `OpenSSL 1.0.2r` because of build issues on Alpine. `1.15.8.1-alpine` and later are built from `OpenSSL 1.1.1` series.

* Windows images must be built from the same version as the host system it runs on.  See [Windows container version compatibility](https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility).  Our images are currently built from the "Windows Server 2016" series.

* If OpenResty logs do not appear in `docker logs` / `docker compose logs` ([#91](https://github.com/openresty/docker-openresty/issues/91)), the usual causes are: (1) a volume bind-mounted over `/usr/local/openresty/nginx/logs`, which shadows the image's log symlinks and silently sends logging to regular files inside the mount — named volumes are unaffected when Docker's default copy behavior is used, but volumes mounted with the `nocopy` option have the same problem, and the [entrypoint](#docker-entrypoint) warns about this at startup; (2) expecting `error_log ... debug;` output from a regular image — debug-level messages require a `-debug` image, such as `bookworm-debug`; (3) on old docker-compose **v1**, the log stream was lost when a container auto-restarted (e.g. `restart: on-failure` crash-looping until an upstream came up) — the logs still reached `docker logs`, and compose v2 fixed this.

* The `SIGQUIT` signal will be sent to nginx to stop this container, to give it an opportunity to stop gracefully (i.e, finish processing active connections).  The Docker default is `SIGTERM`, which immediately terminates active connections.

* Alpine 3.9 added OpenSSL 1.1.1 and we build images against this.  OpenSSL 1.1.1 enabled TLS 1.3 by default, which can create unexpected behavior with ssl_session_(store|fetch)_by_lua*. See this patch, which will ship in OpenResty 1.17.x.1, for more information: https://github.com/openresty/lua-nginx-module/commit/d3dbc0c8102a9978d649c99e3261d93aac547378

Image Labels
============

The image builds are labeled with various information, such as the versions of OpenResty and its dependent libraries.  Here's an example of printing the labels using [`jq`](https://stedolan.github.io/jq/):

```
$ docker pull openresty/openresty:1.17.8.1-0-bionic
$ docker inspect openresty/openresty:1.17.8.1-0-bionic | jq '.[].Config.Labels'
{
  "maintainer": "Evan Wies <evan@*********.net>",
  "resty_add_package_builddeps": "",
  "resty_add_package_rundeps": "",
  "resty_config_deps": "--with-pcre     --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include'     --with-ld-opt='-L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib'     ",
  "resty_config_options": "    --with-compat     --with-file-aio     --with-http_addition_module     --with-http_auth_request_module     --with-http_dav_module     --with-http_flv_module     --with-http_geoip_module=dynamic     --with-http_gunzip_module     --with-http_gzip_static_module     --with-http_image_filter_module=dynamic     --with-http_mp4_module     --with-http_random_index_module     --with-http_realip_module     --with-http_secure_link_module     --with-http_slice_module     --with-http_ssl_module     --with-http_stub_status_module     --with-http_sub_module     --with-http_v2_module     --with-http_v3_module     --with-http_xslt_module=dynamic     --with-ipv6     --with-mail     --with-mail_ssl_module     --with-md5-asm     --with-pcre-jit     --with-sha1-asm     --with-stream     --with-stream_ssl_module     --with-threads     ",
  "resty_config_options_more": "",
  "resty_eval_post_make": "",
  "resty_eval_pre_configure": "",
  "resty_eval_post_download_pre_configure": "",
  "resty_image_base": "ubuntu",
  "resty_image_tag": "bionic",
  "resty_luarocks_version": "3.3.1",
  "resty_openssl_patch_version": "1.1.0d",
  "resty_openssl_url_base": "https://www.openssl.org/source/old/1.1.0",
  "resty_openssl_version": "1.1.0l",
  "resty_pcre_version": "8.45",
  "resty_version": "1.17.8.1"
}
```

| Label Name                               | Description                                                                                                           |
|:-----------------------------------------|:----------------------------------------------------------------------------------------------------------------------|
| `maintainer`                             | Maintainer of the image                                                                                               |
| `resty_add_package_builddeps`            | buildarg `RESTY_ADD_PACKAGE_BUILDDEPS`                                                                                |
| `resty_add_package_rundeps`              | buildarg `RESTY_ADD_PACKAGE_RUNDEPS`                                                                                  |
| `resty_apk_alpine_version`               | buildarg `RESTY_APK_ALPINE_VERSION`                                                                                   |
| `resty_apk_key_url`                      | buildarg `RESTY_APK_KEY_URL`                                                                                          |
| `resty_apk_repo_url`                     | buildarg `RESTY_APK_REPO_URL`                                                                                         |
| `resty_apk_version`                      | buildarg `RESTY_APK_VERSION`                                                                                          |
| `resty_apt_pgp`                          | buildarg `RESTY_APT_PGP`                                                                                              |
| `resty_apt_repo`                         | buildarg `RESTY_APT_REPO`                                                                                             |
| `resty_apt_arch`                         | buildarg `RESTY_APT_ARCH`                                                                                             |
| `resty_config_deps`                      | buildarg `_RESTY_CONFIG_DEPS` (internal)                                                                              |
| `resty_config_options_more`              | buildarg `RESTY_CONFIG_OPTIONS_MORE`                                                                                  |
| `resty_config_options`                   | buildarg `RESTY_CONFIG_OPTIONS`                                                                                       |
| `resty_deb_flavor`                       | buildarg `RESTY_DEB_FLAVOR`                                                                                           |
| `resty_deb_version`                      | buildarg `RESTY_DEB_VERSION` ([available versions](https://openresty.org/package/debian/pool/openresty/o/openresty/)) |
| `resty_eval_pre_make`                    | buildarg `RESTY_EVAL_PRE_MAKE`                                                                                        |
| `resty_eval_post_make`                   | buildarg `RESTY_EVAL_POST_MAKE`                                                                                       |
| `resty_eval_pre_configure`               | buildarg `RESTY_EVAL_PRE_CONFIGURE`                                                                                   |
| `resty_eval_post_download_pre_configure` | buildarg `RESTY_EVAL_POST_DOWNLOAD_PRE_CONFIGURE`                                                                     |
| `resty_fat_deb_flavor`                   | buildarg `RESTY_FAT_DEB_FLAVOR`                                                                                       |
| `resty_fat_deb_version`                  | buildarg `RESTY_FAT_DEB_VERSION`                                                                                      |
| `resty_fat_image_base`                   | Name of the base image to build fat images from, buildarg  `RESTY_FAT_IMAGE_BASE`                                     |
| `resty_fat_image_tag`                    | Tag of the base image to build fat images from, buildarg `RESTY_FAT_IMAGE_TAG`                                        |
| `resty_image_base`                       | Name of the base image to build from, buildarg  `RESTY_IMAGE_BASE`                                                    |
| `resty_image_tag`                        | Tag of the base image to build from, buildarg `RESTY_IMAGE_TAG`                                                       |
| `resty_install_base`                     | buildarg `RESTY_INSTALL_BASE`                                                                                         |
| `resty_install_tag`                      | buildarg `RESTY_INSTALL_TAG`                                                                                          |
| `resty_luajit_options`                   | buildarg `RESTY_LUAJIT_OPTIONS`                                                                                       |
| `resty_luarocks_version`                 | buildarg `RESTY_LUAROCKS_VERSION`                                                                                     |
| `resty_openssl_patch_version`            | buildarg `RESTY_OPENSSL_PATCH_VERSION`                                                                                |
| `resty_openssl_url_base`                 | buildarg `RESTY_OPENSSL_URL_BASE`                                                                                     |
| `resty_openssl_version`                  | buildarg `RESTY_OPENSSL_VERSION`                                                                                      |
| `resty_openssl_build_options`            | buildarg `RESTY_OPENSSL_BUILD_OPTIONS`                                                                                |
| `resty_pcre_build_options`               | buildarg `RESTY_PCRE_BUILD_OPTIONS`                                                                                   |
| `resty_pcre_options`                     | buildarg `RESTY_PCRE_OPTIONS`                                                                                         |
| `resty_pcre_sha256`                      | buildarg `RESTY_PCRE_SHA256`                                                                                          |
| `resty_pcre_version`                     | buildarg `RESTY_PCRE_VERSION`                                                                                         |
| `resty_rpm_arch`                         | buildarg `RESTY_RPM_ARCH`                                                                                             |
| `resty_rpm_dist`                         | buildarg `RESTY_RPM_DIST`                                                                                             |
| `resty_rpm_flavor`                       | buildarg `RESTY_RPM_FLAVOR`                                                                                           |
| `resty_rpm_version`                      | buildarg `RESTY_RPM_VERSION`                                                                                          |
| `resty_strip_binaries`                   | buildarg `RESTY_STRIP_BINARIES`                                                                                       |
| `resty_version`                          | buildarg `RESTY_VERSION`                                                                                              |
| `resty_yum_repo`                         | buildarg `RESTY_YUM_REPO`                                                                                             |


Docker CMD
==========

See also [Docker Entrypoint](#docker-entrypoint): since `1.31.1.1-3`, Linux images define an `ENTRYPOINT` that runs scripts in `/docker-entrypoint.d/` before `exec`ing the command when it is `openresty`/`nginx` (and variants).  The default `CMD` remains a full OpenResty invocation with `-g "daemon off;"`.

The `-g "daemon off;"` directive is used in the Dockerfile CMD to keep the Nginx daemon running after container creation. If this directive is added to the nginx.conf, then the `docker run` should explicitly invoke `openresty` (or `nginx` for `windows` images):
```
docker run [options] openresty/openresty:noble openresty
```

Invoking another command (for example the `resty` utility) skips the entrypoint startup scripts and `exec`s that command directly:
```
docker run [options] openresty/openresty:noble resty [script.lua]
```

On Linux images, replacing the entrypoint entirely (`docker run --entrypoint ...` or Kubernetes `command:`) restores pre-`1.31.1.1-3` behavior; a plain command override (Kubernetes `args:`) still goes through the entrypoint.  See [Docker Entrypoint](#docker-entrypoint) for flag arguments, template rendering, and custom init scripts.

*NOTE* The `alpine` images do not include the packages `perl` and `ncurses`, which is needed by the `resty` utility.


Feedback & Bug Reports
======================

You're very welcome to report bugs and give feedback as GitHub Issues:

https://github.com/openresty/docker-openresty/issues

[Back to TOC](#table-of-contents)


Changelog & Authors
===================

 * [CHANGELOG](https://github.com/openresty/docker-openresty/blob/master/CHANGELOG.md)
 * [AUTHORS](https://github.com/openresty/docker-openresty/blob/master/AUTHORS.md)

[Back to TOC](#table-of-contents)


Copyright & License
===================

`docker-openresty` is licensed under the 2-clause BSD license.

Copyright (c) 2017-2026, Evan Wies <evan@neomantra.net>.

This module is licensed under the terms of the BSD license.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)
