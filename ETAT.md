# mCASTING 2.0 — les langues de son choix (validé le 21/11/2026)

Maquettes validées : `maquettes/multilingue-2.0.html`.

- Chaque projet a 1 ou 2 langues (principale = langue des répliques et du casting). `Project.langs`, `Project.active`
  (langue écoutée) ; projets 1.x relus comme FR + EN, sans perte.
- `Lang` devient un code ISO 639-1 ouvert (`Sources/Core/Languages.swift` : 23 langues, nom natif, phrases d'extrait,
  langues de chaque moteur). Langues de la bibliothèque = celles du créateur de voix (Qwen3 : 10).
- La bibliothèque calcule les langues des projets (+ langues ajoutées), langue par langue, avec pause ; une langue déjà
  calculée n'est jamais refaite. La recette « French-speaking » suit la langue calculée.
- Écoute à la demande dans toute langue d'un modèle installé (clonage du timbre, cache `audio/cache/`), mention de
  l'accent possible dans le menu « Écouter en » et la saisie de texte libre.
- Changement de langue principale : les répliques restent rattachées à leur langue (`altLines`).
- Import (`languages`), CSV (colonne langue = tout code), casting.json (`languages` = langues du projet, format inchangé),
  MCP (`list_languages`, `create_project languages`, `set_project_languages`, `preview_voice lang` = tout code).
- Reste à faire avant la release 2.0 : documentation FR / EN et PDF, notes de version, captures.

# mCASTING — Guide « Premiers pas » : architecture (proposée le 21/11/2026, à valider)

Maquettes validées : `maquettes/guide.html` (version simple, 7 étapes). Version détaillée de référence : `maquettes/guide-detaille.html`.

## 1. Principe clé : deux rôles, et la bibliothèque toujours faite par un modèle « qui sait créer une voix »

- **Assistant IA** (texte) : prépare le projet. Cloud (Claude, ChatGPT…) via le skill + MCP, ou local (Ollama, LM Studio).
- **Modèle de voix** (audio) : parle.
- Seuls certains modèles savent **créer une voix d'après une description** (Qwen3 VoiceDesign, OmniVoice, VoxCPM2).
  Les autres (Fish Audio Drama 3 « voix d'acteur », Chatterbox) savent seulement **cloner** un extrait.
- Donc : la **bibliothèque** est toujours générée par un modèle « créateur » (Qwen3 par défaut). Le modèle choisi à
  l'écoute sert à **dire les répliques** en clonant l'extrait de la voix choisie (comme le mode Fidèle actuel).
  On garde ainsi le même timbre partout, et on peut changer de modèle de jeu sans régénérer la bibliothèque.

## 2. Modules

### Core (partagé app + MCP)
| Fichier | Rôle |
|---|---|
| `Hardware.swift` | Puce (`machdep.cpu.brand_string`), mémoire (`hw.memsize`), disque libre. Niveau Léger / Confort / Studio. Règle : proposé < 50 % RAM, possible ≤ 70 %, masqué au-delà. |
| `ModelCatalog.swift` + `Resources/models.json` | Liste courte des modèles : id, dépôt HF, nom simple (« Voix naturelle »…), capacités (`design`, `clone`, `emotion`, langues), taille, RAM estimée, licence, niveau mini. Fichier livré avec l'appli **et** relu depuis le dépôt GitHub (raw `models.json`) une fois par jour, pour suivre Hugging Face sans mise à jour de l'appli. L'API HF sert seulement à vérifier taille et disponibilité. |
| `VoiceBackend.swift` | Protocole : `capabilities`, `design(recipe:text:lang:)`, `clone(ref:refText:text:lang:instruct:)`, `voices()` (catalogue d'un serveur ou d'un service). |
| `MLXBackend.swift` | Implémentation locale (venv mlx-audio actuel). Un petit adaptateur d'arguments par famille de modèles (Qwen3, Fish, Chatterbox, OmniVoice). Remplace l'appel direct d'`Engine.generate`. |
| `OpenAISpeechBackend.swift` | Serveur local ou réseau (`/v1/audio/speech`, `/v1/models`) : mlx-audio server, LocalAI, Kokoro-FastAPI. Clé éventuelle dans le Trousseau. Pas de création de voix : la bibliothèque = les voix du serveur. |
| `CloudBackend.swift` | ElevenLabs d'abord (clé `~/.config/elevenlabs/.env` ou Trousseau). Estimation du coût avant chaque génération, confirmation obligatoire. Pas de bibliothèque de 600 voix : casting dans le catalogue du service. |
| `ServerDiscovery.swift` | Sonde des ports connus sur localhost (11434 Ollama, 1234 LM Studio, 8080 LocalAI, 8000 mlx-audio, 8880 Kokoro) + Bonjour sur le réseau. Classe chaque serveur : texte ou voix. |
| `DialogueImport.swift` | Étend `ProjectImport` : JSON mcasting-project (actuel), CSV (personnage ; réplique ; langue), texte « NOM : réplique ». Fichiers de langue d'un jeu → confiés à l'assistant IA. |
| `DialogueAnalyzer.swift` | Remplit genre, âge, `kind` (humain / créature / animal), description de voix, émotion par réplique. Assistant local (Ollama `/api/chat` avec schéma JSON) si choisi, sinon heuristiques actuelles (`guessGender`). |
| `AgentInstaller.swift` | Détecte Claude Code (`~/.claude`), Codex (`~/.codex`), Cursor, Claude Desktop. Installe le skill (`Resources/skill/mcasting/SKILL.md`, versionné avec l'appli) et déclare le serveur MCP. Sauvegarde de chaque fichier de config avant modification, désinstallation possible. |
| `ComparisonRunner.swift` | Télécharge les modèles cochés, puis génère 3 répliques réelles × N modèles, à la suite (verrou de calcul existant). Mesure le temps par réplique (affiché « rapide / plus lente »). |
| `CreatureFX.swift` | Effets natifs AVAudioEngine (hauteur, vitesse, distorsion, écho, réverbération) : 3 préréglages par type (géant, dragon, lutin, spectre, robot, chat…). Couche « cri » Stable Audio 3 Small SFX en option, **après essai** (lot 3). |
| `SetupState.swift` | `setup.json` : étape atteinte, choix faits (assistant, modèles, mode voix), terminé ou non. Permet de reprendre le guide. |

### Modèle de données (ajouts rétrocompatibles)
- `Character.kind: String?` (`human` / `creature` / `animal`), `Character.fx: String?` (préréglage d'effet).
- `Voice.backend: String?` (id du moteur ; absent = Qwen3 local, comme aujourd'hui).
- Projet : `actingModel: String?` (modèle qui dit les répliques ; absent = Qwen3).
- Format d'import `mcasting-project/1` : champ `kind` optionnel par personnage ; `casting.json` : `acting_model`, `fx`.

### App (SwiftUI, Flat Mat, 4 langues)
- `SetupWizard.swift` : fenêtre « Premiers pas », 7 écrans des maquettes, une question par écran, choix recommandé
  pré-sélectionné, « Plus tard » partout. Ouverte au premier lancement, à chaque « Nouveau projet » (étapes déjà
  faites sautées : on ne repose que Projet + Dialogues), et par **Aide › Premiers pas**.
- Réglages › Modèles : tout ce que le guide a choisi, modifiable ensuite (vue détaillée, termes techniques autorisés).
- Écran Créatures : n'apparaît que si `kind` ≠ humain pour au moins un personnage.

### MCP
- Nouveaux outils : `get_setup`, `list_models` (avec adéquation au matériel), `analyze_dialogues`.
- `import_project` accepte `kind`. Le skill renvoie à `get_import_guide` pour le format exact.

## 3. Flux du guide
1. Projet → `projects.json`.
2. Préparation → `AgentInstaller` (cloud) ou `ServerDiscovery` (Ollama). Rien d'obligatoire.
3. Dialogues → `DialogueImport` → `DialogueAnalyzer` → personnages avec `kind`.
4. Voix → `Hardware` + `ModelCatalog` → choix du mode (Mac / serveur / cloud) et des modèles à comparer.
5. Écoute → téléchargement + `ComparisonRunner` → `actingModel`.
6. Créatures → `CreatureFX` → `fx` par personnage.
7. Bibliothèque → `LibraryGenerator` (inchangé, Qwen3 VoiceDesign) en arrière-plan, reprise automatique.

## 4. Découpage en lots (chacun livrable seul)
1. **Socle du guide** : fenêtre et 7 écrans, `SetupState`, `Hardware`, `ModelCatalog` (Qwen3 + 2 modèles), `MLXBackend`
   avec clonage multi-modèles, `ComparisonRunner`, Bibliothèque. Assistant et Créatures affichés mais simplifiés.
2. **Assistant IA** : skill + `AgentInstaller`, Ollama + `DialogueAnalyzer`, imports CSV / texte.
3. **Créatures** : `CreatureFX` + écran ; essai réel de Stable Audio 3 Small avant de l'intégrer.
4. **Serveur local et cloud** : `ServerDiscovery`, `OpenAISpeechBackend`, `CloudBackend` (ElevenLabs).

## 5. Risques et vérifications avant de coder
- Vérifier, pour chaque modèle retenu, les arguments réels de `mlx_audio.tts.generate` (clonage, langue, émotion) par
  un essai court. Fish Audio Drama 3 : 22 Go, licence avec mention obligatoire pour un usage commercial (affichée).
- Ollama : confirmer qu'il ne fait toujours pas de voix (seulement texte).
- Modifier la config d'un autre logiciel (Claude Desktop, Cursor) : toujours sauvegarder et demander.
- Durées et tailles affichées = mesurées sur la machine, jamais codées en dur.

## 6. Modèle conseillé pour coder
Architecture et lot 1 : Opus pour `VoiceBackend` / `MLXBackend` (transverse), puis Sonnet pour les écrans, les
textes en 4 langues et les lots 2 à 4.
