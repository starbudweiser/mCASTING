# mCASTING

Local AI voice casting for production projects: a library of ready-made voices, voice cloning, and a per-project casting you can hand to an agent.

## About

mCASTING is part of the **DESKTOP MAC TOOLKIT**. Made by Starbudweiser & Claude Code (Anthropic). MIT License. Provided as is, without warranty: only use voices you have the right to use. See *About mCASTING* in the app menu.

## Documentation

Full documentation, development guide and user interface guide, in French and English: [docs/](docs/README.md).

## What it does

- **Casting per project.** A project (a game, a video, a voice-over…) is a list of characters with a role and sample lines, in one or two languages chosen for the project. You listen to the library and pick each character's voice.
- **Voice library.** ~600 voice recipes (men, women, children, animals, creatures) generated locally with Qwen3-TTS VoiceDesign, with a sample in each of your projects' languages (10 available: English, French, German, Spanish, Italian, Portuguese, Russian, Chinese, Japanese, Korean). A language already computed is reused by every project. Filter by gender, age, tone, language; A/B comparison; emotion set per line.
- **Any voice, any language.** Hear any voice in any language an installed model speaks (up to 23 with Chatterbox multilingual or OmniVoice): its sample is cloned to keep the timbre, and the result is cached. A slight accent may remain, and the app says so.
- **Voice cloning.** Import an audio file (WAV, MP3, M4A…) or a web link (YouTube and other sites, audio only), choose a 15–25 s excerpt, transcribe it and add the cloned voice to the library. You must have the right to use the voice. Cloned voices have their own library, sorted by source type (game, film, series), source, original character, gender, language, tags and use, with an editable record.
- **Line database.** Lines received from other tools (mTALKIE sends game lines with their text, speaker and audio; any tool can drop a package, see [docs/INBOX.md](docs/INBOX.md)) go into a searchable database: full-text search (accents ignored), filters by source, tag, language, length and speaker, playback, export to CSV or JSON. Assign a line to a character, as *inspiration* (rewritten before being spoken) or as *original text* (private tests only); assigned lines go into `casting.json` (`assigned_lines`).
- **Agent-ready (MCP).** A bundled MCP server (`mcasting-mcp`, stdio) lets an agent create projects, add characters, search voices, preview a voice and write the final `casting.json` into your project folder.
- **100% local.** Everything runs on your Mac (Apple Silicon, macOS 15+). The app installs its own isolated Python engine (uv + mlx-audio) and downloads the models you choose from Hugging Face. One heavy generation at a time.

## `casting.json`

```json
{
  "format": "mcasting/1",
  "project": "My game",
  "lang": "fr",
  "characters": {
    "<id>": { "name": "Hero", "role": "…", "voice_id": "man-adult-medium-1", "engine": "qwen3-voicedesign",
              "recipe": "A French-speaking person…", "style": "tired, low energy", "sample": "/…/audio/lib/….m4a" }
  }
}
```

Cloned voices carry `engine: "qwen3-base"`, `ref_audio` and `ref_text` instead of a recipe.

**Several languages, same voice.** A library voice carries its own sample for each language in `samples`. To speak a
language, clone *that language's* sample with the Qwen3-TTS Base model (sample audio as reference, the sample text from the
catalog as reference text): the accent stays native and the voice matches what you heard in the library. Cloning a sample
into another language keeps the timbre but also carries its accent, so `timbre_ref_audio` / `timbre_ref_text` are only a
fallback when no sample exists in the target language. Never re-run VoiceDesign for this (it draws a new timbre every time).
`lines_alt` holds the lines in the other languages when the imported project provides
them (`"lines": {"fr": [...], "en": [...]}`).

## MCP server

*Settings → MCP server* shows the exact command, for example:

```bash
claude mcp add mcasting -- "/Applications/mCASTING.app/Contents/MacOS/mcasting-mcp"
```

Tools: `get_import_guide`, `import_project`, `export_project`, `list_projects`, `create_project`, `add_characters`, `list_characters`, `search_voices` (also by source, source kind, character and tags for cloned voices), `update_voice`, `set_casting`, `unset_casting`, `preview_voice`, `write_casting`, and for the line database `list_line_sources`, `search_lines`, `get_line`, `assign_line`, `unassign_line`.

## Bring an existing project (any agent)

Ask your agent: *"Import this project into mCASTING."* It calls `get_import_guide`, builds a small JSON (`mcasting-project/1`: characters, sample lines, current voices) from your project's files, previews it with `import_project` (`dry_run`), then imports it. Re-importing is safe: characters are matched by id then name, and a casting already done is never erased. You can also import a JSON file from the app (*Projects → Import a project…*). Format and tips: [docs/IMPORT.md](docs/IMPORT.md).

## Build

```bash
./build_app.sh            # build, sign, install in ~/Applications/Applications Personnelles
DEV=1 ./build_app.sh      # development edition (separate bundle id and data folder, not installed)
```

Interface languages: French, English, Spanish, Italian (follows the system language). Voice languages: see above. Design: Flat Mat.
