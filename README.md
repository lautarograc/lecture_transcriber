# lecture_transcriber

Generates a transcript from a recorded lecture video, combining speech and
on-screen slide content into one document with timestamps.

- Speech is transcribed locally with [whisper.cpp](https://github.com/ggerganov/whisper.cpp).
- Slide changes are detected via `ffmpeg` scene-change analysis, and each
  slide is OCR'd with `tesseract`.
- No AI/LLM required or used anywhere in the pipeline. Everything runs
  locally through dedicated, deterministic tools.
- Ships as a single native binary for Linux and Windows.

## Install

### Prerequisites (for building from source, Linux)

- [Elixir](https://elixir-lang.org/install.html) 1.18+ and Erlang/OTP
- [Zig](https://ziglang.org/download/) (used by [Burrito](https://github.com/burrito-elixir/burrito) to build the native binary)
- A Debian/Ubuntu-family host, `cmake`, a C/C++ toolchain, and `pkg-config`
  (`bin/fetch_tools.sh` builds `tesseract` and its image-format dependencies
  from source, statically)

### Build

```bash
mix deps.get
./bin/fetch_tools.sh      # fetches/builds ffmpeg, whisper-cli, tesseract into priv/
MIX_ENV=prod mix release
```

This produces `burrito_out/lecture_transcriber_linux` and
`burrito_out/lecture_transcriber_windows.exe` — standalone binaries with
`ffmpeg`, `whisper-cli`, and `tesseract` all bundled inside. Copy the one for
your platform wherever you like; no other install is needed to run it (not
even Elixir/Erlang, and not `tesseract-ocr` from your system package
manager).

`tesseract`'s normal shared-library build pulls in ~50 libraries via
`libcurl` — a full TLS/Kerberos/LDAP stack it only needs to fetch training
data over the network, irrelevant here. `fetch_tools.sh` instead builds it
statically with that support disabled, so the bundled binary needs nothing
beyond the same base `libc`/`libstdc++` that `ffmpeg` and `whisper-cli`
already require.

To use your own `tesseract` instead of the bundled one, pass
`--tesseract-bin <path>`.

**Licensing note:** the bundled `ffmpeg` is built with `--enable-gpl`. That
doesn't change this project's own MIT license, but if you redistribute the
built binary, GPL's source-availability terms apply to that component.

### Whisper model

Download a [ggml Whisper model](https://huggingface.co/ggerganov/whisper.cpp/tree/main)
(e.g. `ggml-base.en.bin`) and either pass its full path with `--model`, or
put it in a directory and use `--model base.en --models-dir <dir>` (see
Usage below).

## Usage

```bash
lecture_transcriber transcribe <video> --model <path-or-name> [options]
```

This writes `<video-basename>.md` (speech + slides, with embedded slide
images and OCR text, merged chronologically) and `<video-basename>.srt`
(speech only) next to the video, or in `--out-dir` if given.

### Options

| Flag | Description |
|---|---|
| `--model` | Path to a `.bin` model file, or a short name (e.g. `base.en`) resolved against `--models-dir` |
| `--models-dir` | Directory to resolve a short `--model` name against, as `ggml-<name>.bin` |
| `--out-dir` | Output directory for the `.md`/`.srt`/slide images (default: same directory as the video) |
| `--lang` | Spoken language code for transcription (default: `en`) |
| `--no-slides` | Skip slide detection and OCR entirely (audio-only) |
| `--scene-threshold` | Sensitivity for slide-change detection, 0.0-1.0 (default: `0.4`) |
| `--whisper-bin`, `--ffmpeg-bin`, `--tesseract-bin` | Override the binary used for each step |
| `--config` | Path to a config file (default: see below) |

### Config file

Any of the above (except `--out-dir` is `out_dir`, etc. — use snake_case
keys) can be set in a JSON config file instead of passing flags every time:

- Linux: `~/.config/lecture_transcriber/config.json`
- Windows: `%APPDATA%\lecture_transcriber\config.json`

```json
{
  "models_dir": "/home/you/whisper-models",
  "model": "base.en",
  "lang": "en",
  "scene_threshold": 0.4
}
```

CLI flags always override the config file.

### Example

```bash
lecture_transcriber transcribe lecture01.mp4 --model base.en --models-dir ~/whisper-models
```

## License

MIT — see [LICENSE](LICENSE).
