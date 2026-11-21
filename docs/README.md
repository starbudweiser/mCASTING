# mCASTING — Documentation

| | Français | English |
|---|---|---|
| Documentation complète / Full documentation | [fr/DOCUMENTATION.md](fr/DOCUMENTATION.md) | [en/DOCUMENTATION.md](en/DOCUMENTATION.md) |
| Dossier de développement / Development guide (PDF) | [mCASTING-developpement-FR.pdf](pdf/mCASTING-developpement-FR.pdf) | [mCASTING-development-EN.pdf](pdf/mCASTING-development-EN.pdf) |
| Interface graphique / User interface (PDF) | [mCASTING-interface-FR.pdf](pdf/mCASTING-interface-FR.pdf) | [mCASTING-interface-EN.pdf](pdf/mCASTING-interface-EN.pdf) |
| Format d'import pour les agents / Import format for agents | [IMPORT.md](IMPORT.md) | [IMPORT.md](IMPORT.md) |

- `img/`: captures d'écran de l'application (version 2.0) / app screenshots.
- `pdf-src/`: sources HTML des PDF. Pour les régénérer / to rebuild them:

```bash
cd docs && for f in dev-fr dev-en ui-fr ui-en; do
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --no-pdf-header-footer \
    --print-to-pdf="$PWD/pdf/$f.pdf" "file://$PWD/pdf-src/$f.html"; done
```

(Les PDF publiés portent un nom explicite ; renommer après génération. / Published PDFs have explicit names; rename after rebuilding. Any Chromium browser works.)
