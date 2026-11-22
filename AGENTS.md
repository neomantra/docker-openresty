# AGENTS.md

## Repository Overview
This repository contains the Docker tooling and Dockerfiles for OpenResty. It supports multiple Linux distributions (Alpine, Ubuntu, Debian, CentOS, Fedora, etc.) and architectures (amd64, arm64, s390x, ppc64le).

## CI/CD Architecture
The project has migrated from Travis CI to **GitHub Actions**.

### Workflow
The primary workflow is defined in `.github/workflows/docker-publish.yml`.
- **Primary Registry**: GitHub Container Registry (GHCR). All images are built and pushed here first.
- **Mirror Registry**: Docker Hub (`openresty/openresty`). This is configured as a mirror. Pushing to Docker Hub is optional and controlled by the `ENABLE_DOCKERHUB_MIRROR` variable/secret.
- **Fat Images**: "Fat" images (containing additional build tools like OPM) are built in a second stage (`build-fat` job), using the base images newly published to GHCR.

### Workflows
- `docker-publish.yml`: Handles building, smoke-testing (`restyrepo`), and publishing images across flavors and architectures.
- `restyrepo-master.yml`: Manually dispatched workflow that resolves OpenResty's upstream `master` commit, builds and smoke-tests `restyrepo` across `amd64`, `arm64`, `s390x`, and `ppc64le`, and publishes `restyrepo-master` to GHCR (and optionally Docker Hub).

## Verification
- `tests/smoke/smoke.sh`: In-container smoke tests for source-built images.
- `tests/e2e/run-test.sh`: Local registry and `act` end-to-end build verification script.

## Key Files
- `.github/workflows/docker-publish.yml`: Main CI definition.
- `.github/workflows/restyrepo-master.yml`: Manual upstream snapshot CI workflow.
- `README.md` / `BUILDING.md`: User-facing and build documentation.

## Historical Context
- Previously used Travis CI (`archive/dot_travis.yml` - removed).
- Previously Windows builds were handled by AppVeyor (`archive/appveyor.yml`).
