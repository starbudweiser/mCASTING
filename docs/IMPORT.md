# Importing an in-progress project

This page is also served to agents by the MCP tool `get_import_guide`, the MCP resource `mcasting://import-guide` and the MCP prompt `import_project`.

```text
mCASTING — importing an in-progress project (format "mcasting-project/1")

GOAL: give mCASTING the list of characters (and, if they exist, their current voices) of a project so the user can cast voices for it.
Works with any agent: build the JSON below from the project's files (script, dialogue data, game manifests…), then call the import_project tool
(project_json = the JSON text, or path = absolute path of a .json file you wrote). Use dry_run=true first to preview. Re-importing is safe:
characters are matched by "id" (your stable identifier) then by name, new ones are added, existing ones updated, and a casting already done is never erased.

SCHEMA
{
  "format": "mcasting-project/1",
  "name": "Project name (required)",
  "lang": "fr" | "en"                      // language of the voices to cast (default fr)
  "folder": "/absolute/path/of/the/project" // where casting.json will be written (optional but recommended)
  "characters": [
    {
      "id": "hero",                         // stable identifier in the source project (recommended)
      "name": "Hero",                       // required
      "role": "young deadpan adventurer",   // short description of who they are and how they should sound
      "notes": "free text (age, accent, relationships…)",
      "line_count": 383,                    // total number of lines the character speaks (optional)
      "lines": ["a few representative lines", "…"]   // or {"fr": [...], "en": [...]} ; 5–20 varied lines are plenty
      "current_voice": {                    // only if the project already has a voice for this character
        "description": "how it was generated / what it sounds like",
        "engine": "qwen3-customvoice",
        "samples": [ { "file": "/absolute/path/to/sample.mp3", "text": "what is said in the sample" } ]
      }
    }
  ]
}

TIPS FOR THE AGENT
- Prefer a file ("path") for big projects. Absolute paths only for "folder" and sample "file"s.
- Pick lines that show the character's range (calm, angry, joking…). Keep texts exactly as spoken.
- Do not invent characters; one entry per speaking character (narrator included if it speaks).
- Next steps after import: search_voices → set_casting → preview_voice → write_casting (writes casting.json into "folder").
- export_project returns a project in this same format, casting included.
```
