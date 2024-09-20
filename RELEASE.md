# Release Process

This policy applies to Beacon, BeaconLiveAdmin, and any other project in the BeaconCMS organization.

## Guidelines

1. Follow [Semantic Versioning](https://semver.org/)

   * For projects on v0.x releases, breaking changes are released as minor versions., for example in v0.2.0
   * For projects on v1.x releases, breaking changes are released as major versions., for example in v2.0.0

2. Each project has its own lifecycle and releases, one may evolve faster than others

3. A new major or minor version is released once a month containing features, fixes, and potentially breaking changes.

   * The type of the version, either major or minor is decided based on the changes included in that release and the current version.
   * We might skip releasing a new version if there's no changes in that period of time.

5. Bug fixes and security patches are released as soon as possible, either as a patch or minor version depending on the current version.

## Git strategy

Change are applied to the `main` branch through feature branches. A pull requested is opened, reviewed, and merged to `main`
once it's ready to avoid merge conflicts and make that code available on `main` in case anyone wants to test or use it.

Along with the `main` and feature branches, we also keep release branches for each version, for example `v0.1.x`, `v2.0.x`, and so on.
Changes are cherry-picked from `main` to the release branches as needed, for example if the current published version is `v0.1.1` and
a bug fix is merged into `main`, it will be cherry-picked into the `v0.1.x` branch and a new `v0.1.2` version will be released. Similarly,
if a new feature is merged or a breaking change is introduced, it will also be cherry-picked into a release branch but this time
into the `v0.2.x` branch because new features and breaking changes require a version bump.

## Release steps

1. Checkout the release branch and make sure it's up to date with upstream
2. Make sure all the changes have been cherry-picked from `main` to the release branch
3. Run `mix assets.build` and commit changes if any
4. Update the version in these files: `mix.exs`, `package.json`, and `installation.md`
5. Make sure all relevant changes, especially breaking changes, are documented in a upgrade guide in `guides/upgrading`
6. Update the `CHANGELOG.md` to list all changes included in the release, update the date of the release, and remove unrelated entries (like future unreleased changes that may have been added in `main`)
7. Commit the changes
8. Create a new git tag and push upstream
9. Create a new GitHub release from the tag and include the changes from the `CHANGELOG.md` in the release notes
10. Publish the package to [Hex.pm](https://hex.pm) package registry

## Prioritization

Issues tagged as [roadmap](https://github.com/BeaconCMS/beacon/labels/roadmap) indicate the work that is planned to be worked
next on the short term, those have more priority over the other issues and will be included in the next releases.

Voting on [Feature Requests on our Discussion forum](https://github.com/orgs/BeaconCMS/discussions/categories/feature-requests)
also helps us to prioritize the work, so feel free to vote on the features you'd like to see implemented and those will have more
priority over the other issues.

Finally keep in mind that we don't guarantee which exact issues will be included in the very next release and we may give more
priority to specific issues as decided by the core team as needed.
