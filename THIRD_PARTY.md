# Third-party components and references

The current source tree has no vendored libraries, external Swift package
dependencies, copied application bundles, language models or image assets.
It imports Apple system frameworks supplied by the macOS SDK. System frameworks
are not redistributed or relicensed by this repository.

Codex CLI and Claude applications are optional external integrations, installed
separately under their respective terms. This project is not affiliated with or
endorsed by OpenAI, Anthropic or Apple. Product names identify integrations.

[Vorssaint utilities](https://github.com/vorssaint/vorssaint-utils) was consulted
during earlier design exploration. No Vorssaint source file, binary, logo or
asset is bundled in the reviewed tree. This inventory is based on the available
files, not a forensic guarantee of the provenance of every line. Any future
reuse must be checked against the upstream license and attributed explicitly.

Whisper is not included or implemented. Its name in earlier planning described
a possible future integration, not a bundled dependency.
