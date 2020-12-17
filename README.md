

# CI/CD Installation with Gitlab

### Links

https://docs.gitlab.com/ee/ci/runners/README.html#group-runners
https://docs.gitlab.com/runner/install/osx.html
https://gitlab.com/beamgroup/beam/-/settings/ci_cd#js-runners-settings

https://docs.gitlab.com/runner/register/:
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "PROJECT_REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "docker-runner" \
  --tag-list "docker,aws" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected"

brew cask install provisionql

