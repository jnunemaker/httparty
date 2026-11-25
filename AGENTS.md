# httparty

## Development

- `bundle install`, then `bundle exec rake` runs the RSpec suite (`spec/`) and the Cucumber features (`features/`). Both must pass.
- New behavior needs tests.
- Supports Ruby >= 2.7 (`required_ruby_version` in `httparty.gemspec`); CI runs a matrix of versions, so avoid newer-only syntax.
- Don't change `lib/httparty/version.rb` except when preparing a release.

## Releasing

1. Bump `lib/httparty/version.rb` and merge to `main`.
2. On an up-to-date `main`: `script/release`. It builds the gem to read the version, checks the tag doesn't exist, then tags `vX.Y.Z` and pushes `main` and the tag. It does not push to RubyGems.
3. The tag runs `.github/workflows/release.yml`, which builds the gem, fails if the tag doesn't match the gem version, publishes it to RubyGems via trusted publishing (no API key or OTP), and creates the GitHub Release with notes generated from merged PRs. Check it with `gh run list --workflow release.yml`.

`Changelog.md` points to GitHub Releases for everything since 0.22; don't add entries to it.
