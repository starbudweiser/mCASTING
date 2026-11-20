# mCASTING — architecture (validée le 20/11/2026)

**Application publique** (GitHub public, releases notarisées, licence MIT) : utilisable par n'importe qui pour
caster les voix IA locales d'un projet. Aucune dépendance à un outil, chemin ou donnée de l'auteur.

- `Sources/Core` : modèles, stockage JSON, moteur TTS, générateur, export casting (partagé app + MCP).
- `Sources/App` : SwiftUI, design Flat Mat (maquettes : `maquettes/maquettes-flatmat.html`), 4 langues, mise à jour auto.
- `Sources/MCP` : exécutable `mcasting-mcp` (stdio, JSON-RPC) embarqué dans le paquet ; opère sur les mêmes fichiers.
- Données : `~/Library/Application Support/mCASTING/` (`projects.json`, `voices.json`, `audio/`, `engine/`).
- Moteur autonome : `uv` téléchargé, venv Python 3.12 privé, `pip install mlx-audio`, modèles Hugging Face
  (Qwen3-TTS VoiceDesign/CustomVoice/Base 8 bits) téléchargés à la demande avec vérification.
- Calcul : une seule génération à la fois (verrou `flock` partagé app/MCP).
- Bibliothèque : 600 recettes générées combinatoirement (genre × âge × registre × ton, animaux, créatures),
  1 échantillon FR + 1 EN par recette (~1 200 appels).

## Clonage de voix (ajouté le 20/11/2026)
Panneau « Cloner une voix » : import d'un fichier audio (wav, mp3, m4a, aiff, vidéo) ou d'un lien web (yt-dlp installé
dans le venv privé ; YouTube et autres) → choix de l'extrait (5 à 15 s) → transcription automatique (mlx-audio STT)
→ voix « clonée » (moteur Qwen3 Base, extrait + texte de référence) ajoutée à la bibliothèque. Case obligatoire :
l'utilisateur certifie avoir le droit d'utiliser cette voix (consentement). Format casting.json : `engine: qwen3-base`
+ `ref_audio`/`ref_text` pour les voix clonées.
