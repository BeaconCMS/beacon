# Release Process

This policy applies to Beacon, BeaconLiveAdmin, and any other project in the BeaconCMS organization.

## Guidelines

1. Follow [Semantic Versioning](https://semver.org/)

   * For projects on v0.x releases, breaking changes are released as minor versions, for example in v0.2.0
   * For projects on v1.x releases, breaking changes are released as major versions, for example in v2.0.0

2. Each project has its own lifecycle and releases, one may evolve faster than others.

3. A new major or minor version is released once a month on the first Wednesday of the month, containing features, fixes, and potentially breaking changes.

   * The type of the version, either major or minor is decided based on the changes included in that release and the current version.
   * We might skip releasing a new version if there are no changes in that period of time.

5. Bug fixes and security patches are released as soon as possible, either as a patch or minor version depending on the current version.

## Git strategy

Changes are applied to the `main` branch through feature branches. A pull request is opened, reviewed, and merged into `main`
once it's ready to avoid merge conflicts and make that code available on `main` in case anyone wants to test or use it.

Along with the `main` and feature branches, we also keep release branches for each version, for example `v0.1.x`, `v2.0.x`, and so on.
Changes are [cherry-picked](https://github.com/googleapis/repo-automation-bots/tree/main/packages/cherry-pick-bot) from `main` into the release branches as needed, for example if the current published version is `v0.1.1` and
a bug fix is merged into `main`, it will be cherry-picked into the `v0.1.x` branch and a new `v0.1.2` version will be released. Similarly,
if a new feature is merged or a breaking change is introduced, it will also be cherry-picked into a release branch but this time
into the `v0.2.x` branch because new features and breaking changes require a version bump.

## Release steps

1. Checkout the `main` branch and make sure it's up to date with upstream
2. Run `mix assets.build`
3. Update the `CHANGELOG.md` file and move all items from "Unreleased" to a new version section (the one being released),
   and leave unfinished or incomplete item in "Unrelease" section (the ones that will not be included in the release).
5. Commit the changes to upstream `main` if necessary
6. Checkout the release branch and make sure it's up to date with upstream.
   The release branch is usually the minor version of current version, for eg: `v0.1` branch for a `v0.1.5` release.
   Create a new branch if releasing a new minor or major version.
8. Make sure all the relevant changes have been cherry-picked from `main` to the release branch
3. Update the `CHANGELOG.md` to remove the "Unreleased" section, it should display this release as latest version.
7. Update the version in the files `mix.exs` and `package.json` and throughout docs/ files
8. Run `mix assets.build`
9. Make sure all relevant changes, especially breaking changes, are documented in an upgrade guide in `guides/upgrading`
10. Commit the changes
11. Create a new git tag and push upstream

```sh
git tag -a v0.1.0 -m "v0.1.0"
git push --tags
```

12. Publish the package to [Hex.pm](https://hex.pm) package registry

```sh
mix hex.publish
```

13. [Create a new GitHub release](https://github.com/BeaconCMS/beacon/releases/new) from the tag and include the changes from the `CHANGELOG.md` in the release notes
