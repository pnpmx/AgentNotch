# AgentNotch product demo

Editable 34-second product demo: 1920 × 1080, 30 fps, with an original
instrumental score and synchronized UI sounds. No voiceover.
The UI is an illustration with sample usage values, not a live screen recording.
No account data, transcripts, desktop screenshots, external fonts or third-party
media assets are included. The recreated UI follows the production app's black
panel, cyan/mint Codex accent, orange Claude accent, compact usage rows and
language/refresh controls. Values illustrate fresh sample data, not a live account.

## Preview

From this directory, with Node.js and npm installed:

```sh
npm ci
npm run dev
```

Select `AgentNotchDemo` in Remotion Studio. Individual scenes are also available
under `Scenes`. Text and layout are editable in `src/scenes`; shared notch UI
is in `src/ui.tsx`. The sequence and durations are in `src/Root.tsx`.
Press Play and unmute Studio to hear the audio. The full score is attached to
`AgentNotchDemo`; standalone scene previews are silent.

The visual direction uses neutral backgrounds, centered product framing,
smaller system-font headings and gentle eased motion. Neutral presentation
styling does not recolor the product: cyan/orange usage accents and the red
recording indicator are preserved. No Apple branding or marketing assets are used.

| Time | Scene |
| --- | --- |
| 0–5 s | Introduction |
| 5–13 s | Usage limits and reset times |
| 13–22 s | Hold Space, recording indicator, release to paste |
| 22–28 s | On-device speech |
| 28–34 s | Repository and platform requirements |

## Audio

`public/audio/agentnotch-score.wav` is an original, deterministic synthesized
score (34 seconds, stereo PCM) with expansion and Space-key clicks and a
transcription confirmation tone. It contains no third-party samples or melodies.
The source generator and generated audio are MIT-licensed with this project.

Regenerate with `npm run audio`. The generator reports peak and RMS levels and
applies a fade-in, fade-out and peak ceiling of approximately −8 dBFS.
If scene timings change, update the audio event times in
`scripts/generate-audio.mjs` and regenerate the file.

## Checks and optional export

```sh
npm run lint
npx remotion render AgentNotchDemo out/agentnotch-demo.mp4
```

Rendering may download a compatible Chromium browser. To use an existing Chrome
installation on macOS, append
`--browser-executable="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`.
Generated output and dependencies are excluded from Git.

## License

Original demo source is covered by the repository's MIT license. Dependencies
retain their own licenses: React is MIT; Remotion has separate terms and may
require a commercial license for some uses. See the license bundled with the
installed Remotion packages and [Remotion's license](https://github.com/remotion-dev/remotion/blob/main/LICENSE.md).
The npm lockfile records dependency versions. This demo toolchain is optional
and is not linked into the native macOS application.
