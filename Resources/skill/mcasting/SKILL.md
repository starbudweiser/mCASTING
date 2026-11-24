---
name: mcasting
description: Prepare and run the voice casting of any project that needs AI voices (game, video, voice-over, tutorial, trailer, audiobook, dialogue) with the local app mCASTING, before generating any voice. Use it whenever a project needs character voices, to structure its characters and lines, import them into mCASTING, let the human listen and choose, then read casting.json to generate the lines.
---

# mCASTING — voice casting for a project

mCASTING is a local macOS app (DESKTOP MAC TOOLKIT) that holds a library of hundreds of AI voices and lets a human
cast one voice per character by ear. You prepare the project, the human chooses, then you generate from `casting.json`.
Never pick a voice yourself "by description" and never clone a voice at random: the human validates every choice.

## 1. Structure the project
Read the project's files (script, dialogue data, game language files, subtitles…) and build one entry per speaking
character (narrator included if it speaks). Do not invent characters.

For each character:
- `id`: stable identifier from the source project (file key, variable name…).
- `name`: as shown to the player or viewer.
- `role`: one short sentence saying who they are **and how they should sound** (age, gender, energy, accent, attitude).
  Example: "old absent-minded wizard, elderly man, warm and shaky voice".
- `kind`: `human`, `creature` or `animal` (non-human characters get creature voices and generated cries).
- `notes`: anything else useful (relationships, accent, running gags).
- `lines`: 5 to 20 varied lines that show the character's range (calm, angry, joking…), exactly as spoken.
  If the project has several languages: `"lines": {"de": [...], "en": [...]}`, same order in each language.

**Languages.** Any project chooses 1 or 2 voice languages (ISO 639-1 codes, main one first): set `"languages": ["de", "en"]`
in the import JSON (or `create_project` / `set_project_languages`). Call `list_languages` first: project languages must be
*library* languages (the app computes the library samples in them); any voice can also be heard in every *listen* language
by cloning its timbre (`preview_voice` with `lang`), with a possible slight accent.

## 2. Import into mCASTING
Call the MCP tool `get_import_guide` for the exact schema (format `mcasting-project/1`), write the JSON to a file,
then call `import_project` with `path` (use `dry_run: true` first). Re-importing is safe: characters are matched by
`id`, a casting already done is never erased. Set `folder` to the project folder: `casting.json` is written there.

Without the MCP server, save the same JSON as a file and tell the human to load it in mCASTING (Getting started guide,
step "Dialogue", or Projects › Import).

## 3. Let the human cast
Optionally help with `search_voices` (filters: gender, age, tone) and `preview_voice` (a character's line in a voice),
and suggest candidates with `set_casting` — but tell the human to **listen and validate in the app**. Do not continue
until they say the casting is done.

## 3 bis. Pick lines from the line database (optional)
Lines received from mTALKIE (games) or other tools are searchable: `list_line_sources`, then `search_lines` (text, source,
character, lang, tags, duration). `assign_line` gives a line to a character. Default mode `inspiration`: rewrite the line
for the character in `text` (game, film and series lines and actors' voices are copyrighted; required for anything
published). Mode `original` keeps the exact words, for private tests only. Assigned lines appear in `casting.json` as
`assigned_lines` (`text` to speak, `original`, `source`, `mode`, `emotion`).

## 4. Generate from casting.json
`write_casting` writes `<folder>/casting.json` (format `mcasting/1`). For each character it gives:
- `voice_id`, `recipe` (voice description), `samples` (one audio sample of the voice per language), `style`.
- `acting_model`: the model chosen to speak the lines. Speak each line by **cloning the voice sample in the line's
  language** (`samples.<lang>` as reference audio) with that model. Cloning a sample into another language keeps the
  timbre but also its accent: use `timbre_ref_audio` / `timbre_ref_text` only when no sample exists in that language.
- `ref_audio` / `ref_text` for cloned voices.
- `engine: "server"`: a voice of a network voice server — POST `<server>/v1/audio/speech` with `model` = `remote_model`,
  `voice` = `remote_voice`. `engine: "elevenlabs"`: an ElevenLabs voice (`remote_voice` = voice_id) — it costs credits:
  tell the human the number of characters and get their go-ahead before generating.
- `lines_alt`: the lines in the other languages.
- `sfx`: a generated cry (no words) for creatures and animals, to play alone or mix under the voice.
- `fx` / `fx_ffmpeg`: the voice effect chosen for a creature or animal. Apply `fx_ffmpeg` to every generated line
  (`ffmpeg -i line.wav -af "<fx_ffmpeg>" out.wav`) so the lines sound like what the human chose.

Never regenerate a library voice from its recipe with a voice-design model: it draws a new timbre every time.
