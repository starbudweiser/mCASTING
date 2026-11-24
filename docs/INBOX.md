# mCASTING inbox — package format `mcasting-inbox/1`

Any tool can hand voices and lines to mCASTING by dropping a **package** (a folder) into
`~/Library/Application Support/mCASTING/Inbox/`. mCASTING imports it automatically (while the app runs, or at the next
MCP call), then deletes it. A package that cannot be imported moves to `Inbox/failed/` with an `error.txt`.

Write the package under a name starting with `.` (e.g. `.lines-1712345678.tmp`), then rename it: hidden folders are
never read, so a package is never imported half-written.

```
Inbox/lines-1712345678/
  manifest.json
  audio/gb_0412.aac …
```

## `kind: "voice"` — a voice to clone

```json
{
  "format": "mcasting-inbox/1",
  "kind": "voice",
  "origin": { "app": "mTALKIE", "version": "1.6.0" },
  "source": { "kind": "game", "title": "Escape from Monkey Island", "id": "emi" },
  "voice": { "name": "Guybrush (EMI)", "lang": "en", "gender": "man", "description": "young man, cheerful",
             "audio": "voice.wav", "text": "Exact transcript of voice.wav." }
}
```

`audio`: 15–25 s of clean speech (any format `afconvert` reads); it is converted to mono 24 kHz. `text` must be the exact
transcript (it is the cloning reference). `gender`: man, woman, child, animal or creature. Sending the same `name` from
the same source again replaces the voice.

## `kind: "lines"` — lines for the line database

```json
{
  "format": "mcasting-inbox/1",
  "kind": "lines",
  "origin": { "app": "mTALKIE" },
  "source": { "kind": "game", "title": "Escape from Monkey Island", "id": "emi" },
  "lines": [
    { "key": "guyall159", "text": "Here, monkey monkey monkey…", "character": "Guybrush", "lang": "en",
      "duration": 1.5, "tags": ["exclamation"], "audio": "audio/guyall159.aac" }
  ]
}
```

`source.kind`: game, film, series or other. All line fields are optional except one of `text` / `audio`. Known tags:
laugh, scream, insult, greeting, question, threat, exclamation (others are kept as is). Sending lines for a source `id`
that already exists replaces all of that source's lines.

Game, film and series lines and actors' voices are copyrighted: use them for private tests, and rewrite lines
(*inspiration* mode) before any public use.
