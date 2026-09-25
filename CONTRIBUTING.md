# Contributing

Requires macOS 26 or later and Swift 6.2 or later. The app currently builds for
Apple Silicon. The Swift package has no third-party package dependencies.

```sh
swift build -c release -Xswiftc -warnings-as-errors
swift run -c release AgentNotch --self-test
zsh -n scripts/build-app.sh scripts/install-local.sh scripts/configure-claude.sh
```

The four built-in self-tests cover parsing and date formatting only. There is
currently no XCTest target. For UI, keyboard or speech changes, include a
reproduction and test the affected behavior in an installed GUI build. Use
synthetic text in an isolated editor; never test pasting into a live terminal
command or a real message composer.

Read [AUDIT.md](AUDIT.md) for open defects and required regression checks.
Keep runtime data, app bundles, screenshots of private applications and signing
credentials out of patches. Use synthetic fixtures. Contributions are under
the project's MIT license; include attribution and compatible license notices
when adding third-party code or assets.
