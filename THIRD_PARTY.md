# Third-party components and references

The native application has no vendored libraries, external Swift package
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

The optional `demo/` video project uses Remotion, React and npm development
dependencies recorded in `demo/package-lock.json`. These are not linked into
the native application. Original demo source is MIT; dependencies retain their
own licenses. In particular, Remotion has separate licensing terms and may
require a commercial license for some uses. See `demo/README.md` and the license
files distributed with those packages. The demo's UI is recreated in code with
sample values; it contains no private screen recordings or third-party media.
Its instrumental score and UI sounds are synthesized by the included
`demo/scripts/generate-audio.mjs`; the generator and audio are MIT-licensed
original project assets, without sampled recordings.
