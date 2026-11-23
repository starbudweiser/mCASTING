# mCASTING — Documentation

*Version 2.0.0 · DESKTOP MAC TOOLKIT · Starbudweiser & Claude Code (Anthropic) · Licence MIT*

mCASTING est une application macOS de **casting de voix IA locales**. Pour tout projet qui a besoin de voix (jeu, vidéo, voix off, tutoriel, bande-annonce, livre audio), vous décrivez les personnages, vous écoutez une bibliothèque d'environ 600 voix dans les langues de votre choix, vous choisissez une voix par personnage à l'oreille, puis vous transmettez le résultat à un agent IA ou à un script de génération sous la forme d'un fichier `casting.json`.

Documents associés :
- [Dossier de développement (PDF)](../pdf/mCASTING-developpement-FR.pdf) : architecture, données, formats, MCP, compilation.
- [Interface graphique (PDF)](../pdf/mCASTING-interface-FR.pdf) : design, couleurs, composants, écrans.
- [Format d'import pour les agents](../IMPORT.md).

![Écran Casting](../img/casting-dark.jpg)

---

## Sommaire

1. [Installation](#1-installation)
2. [Premier lancement : le guide « Premiers pas »](#2-premier-lancement--le-guide--premiers-pas-)
3. [Projets](#3-projets)
4. [Casting d'un projet](#4-casting-dun-projet)
   - [Langues du projet et écoute dans d'autres langues](#langues-du-projet-et-écoute-dans-dautres-langues)
5. [Bibliothèque de voix](#5-bibliothèque-de-voix)
6. [Cloner une voix](#6-cloner-une-voix)
7. [Modèles de voix](#7-modèles-de-voix)
8. [Créatures et animaux](#8-créatures-et-animaux)
9. [Travailler avec un assistant IA](#9-travailler-avec-un-assistant-ia)
10. [Voix fabriquées ailleurs : serveur réseau et ElevenLabs](#10-voix-fabriquées-ailleurs--serveur-réseau-et-elevenlabs)
11. [Le fichier casting.json](#11-le-fichier-castingjson)
12. [Serveur MCP](#12-serveur-mcp)
13. [Réglages et mises à jour](#13-réglages-et-mises-à-jour)
14. [Données, confidentialité et droits](#14-données-confidentialité-et-droits)
15. [Questions fréquentes et dépannage](#15-questions-fréquentes-et-dépannage)

---

## 1. Installation

**Configuration requise :** Mac à puce Apple (M1 ou plus récent), macOS 15 ou plus récent. Prévoyez de l'espace disque pour les modèles (3 à 30 Go selon vos choix) et la bibliothèque (environ 1 Go).

1. Téléchargez la dernière version sur la page des releases GitHub : `github.com/starbudweiser/mCASTING/releases`.
2. Décompressez le zip et placez `mCASTING.app` dans votre dossier Applications.
3. Ouvrez l'application. Elle est signée et notarisée par Apple.

Au premier besoin, mCASTING installe son propre moteur de synthèse dans son dossier de données : un environnement Python isolé avec mlx-audio. Rien n'est installé dans le système, et aucun compte n'est demandé.

## 2. Premier lancement : le guide « Premiers pas »

Au lancement, un splash animé s'affiche trois secondes, puis la fenêtre principale s'ouvre. Au premier lancement, et à chaque nouveau projet, le guide **Premiers pas** vous accompagne. Une question par écran, le choix conseillé déjà sélectionné ; « Plus tard » est toujours possible, et le guide reste accessible par le menu de l'icône (*Premiers pas…*).

| Étape | Ce que vous faites |
|---|---|
| **1. Projet** | Donnez un nom, choisissez le dossier où `casting.json` sera écrit et les langues des voix : une principale et, si vous voulez, une secondaire, parmi les 10 langues du créateur de voix. |
| **2. Préparation** | Choisissez si une IA prépare votre projet : l'IA que vous utilisez déjà (Claude, ChatGPT, Cursor…), une IA installée sur votre Mac (Ollama, LM Studio), ou aucune. |
| **3. Dialogues** | Déposez vos répliques : fichier de projet mCASTING (JSON), tableau CSV (`personnage ; réplique ; langue`) ou texte (`NOM : réplique`). |
| **4. Voix** | Choisissez où fabriquer les voix : sur ce Mac (modèles adaptés à votre matériel), sur un autre ordinateur du réseau, ou avec un service en ligne (ElevenLabs). |
| **5. Écoute** | Les modèles cochés disent les mêmes répliques de votre projet ; vous choisissez celui qui jouera vos personnages. |
| **Créatures** | (Seulement si votre projet en a.) Voix suggérées, effets de voix et cris générés. |
| **6. Bibliothèque** | mCASTING fabrique les 600 voix dans les langues du projet, en arrière-plan ; vous pouvez caster pendant ce temps. |

![Guide, étape Projet : les deux langues du projet](../img/guide-1-projet.jpg)

![Guide, étape Voix](../img/guide-4-voix.jpg)

**Assistant IA ou modèle de voix ?** Ce sont deux rôles différents. L'*assistant IA* travaille sur du texte : il lit votre projet et décrit les personnages. Le *modèle de voix* fabrique l'audio. Vous pouvez utiliser l'un sans l'autre.

## 3. Projets

La page **Projets** affiche une carte par projet : ses langues, nombre de personnages, nombre de personnages castés, barre d'avancement et état du fichier `casting.json`.

- **Nouveau projet** ouvre le guide sur les étapes utiles.
- **Importer un projet…** charge un fichier JSON au format `mcasting-project/1`.
- Cliquez sur une carte pour ouvrir le projet dans Casting.
- La **corbeille** d'une carte retire le projet de mCASTING après confirmation. Son dossier et son fichier `casting.json` ne sont pas touchés.

## 4. Casting d'un projet

![Casting, thème clair](../img/casting-light.jpg)

1. **Choisissez un personnage** dans la colonne de gauche. « Ajouter un personnage » en crée un nouveau.
2. Dans l'onglet **Choisir une voix**, le panneau du personnage rappelle son rôle, sa voix actuelle s'il en a une, et l'interprétation.
3. **Filtrez** la bibliothèque à droite : recherche libre, genre, âge, ton, langue, favoris.
4. Sur chaque carte de voix :
   - ▶ écoute l'extrait de la voix dans la langue écoutée ;
   - le menu de langue (**FR ▾**) fait écouter la voix dans une autre langue (voir plus bas) ;
   - **Réplique du perso** fait dire une réplique de votre personnage par cette voix ;
   - **Comparer** lance une écoute A/B avec une autre voix ;
   - **Choisir** attribue la voix au personnage ;
   - l'étoile la met dans vos favoris.
5. **Fidèle ou Expressive** :
   - *Fidèle* garde le timbre exact de l'extrait, sans émotion ;
   - *Expressive* applique l'interprétation choisie (neutre, fatigué, joyeux, colère, ou une consigne libre).
6. Quand le casting est fait, cliquez sur **Écrire casting.json** : le fichier est créé dans le dossier du projet.

L'onglet **Fiche du personnage** permet de modifier le nom, le rôle, les notes et les répliques d'exemple, d'essayer chaque réplique, et de régler l'interprétation par défaut.

Astuce : un clic droit sur la liste des personnages (ou une sélection multiple) attribue des voix aléatoires, ce qui est pratique pour un premier jet.

### Langues du projet et écoute dans d'autres langues

Chaque projet a **une ou deux langues** : la *principale* (celle des répliques et du casting) et une *secondaire* facultative. Elles se choisissent à la création du projet, puis à tout moment avec le bouton **＋** de la barre latérale (*Langues du projet*).

![Fenêtre Langues du projet](../img/langues-projet.jpg)

- **Langues possibles** : celles du modèle qui crée les voix de la bibliothèque, soit 10 langues avec Qwen3-TTS : français, anglais, allemand, espagnol, italien, portugais, russe, chinois, japonais et coréen. Chaque langue s'affiche dans sa propre écriture, son nom traduit au survol.
- **Bibliothèque** : les extraits sont calculés sur votre Mac dans les langues des projets. Une langue déjà calculée pour un autre projet n'est jamais refaite. Avant d'appliquer, la fenêtre indique ce qui est prêt et ce qui reste à calculer, avec la durée estimée.
- **Langue écoutée** : dans la barre latérale, cliquez sur l'une des langues du projet (FR, DE…) ; les cartes de voix, le filtre *Langue* et les répliques de la fiche passent dans cette langue. Sous les langues, l'avancement s'affiche tant qu'une langue n'est pas complète, et le badge d'une voix est orange (« FR · DE… ») quand une langue du projet lui manque encore.
- **Écouter une voix dans n'importe quelle langue** : le menu de langue de chaque carte liste d'abord les langues du projet (extrait prêt, écoute immédiate), puis toutes les autres langues que sait dire un modèle installé, jusqu'à 23 avec Chatterbox multilingue ou OmniVoice. La phrase type de la langue est alors dite **avec le même timbre**, par clonage de l'extrait de la voix ; le résultat est gardé en cache. *Texte libre…* fait dire la phrase de votre choix.
- **Accent** : dans une autre langue que celle de son extrait, la voix garde son timbre mais peut conserver un léger accent. L'appli le rappelle dans le menu et la saisie de texte libre.
- **Émotion** : le clonage garde le timbre exact sans émotion (mode *Fidèle*) ; le mode *Expressive* joue l'émotion, avec un timbre approché. Garder les deux à la fois dépend du modèle et viendra avec ses prochaines versions.
- **Répliques par langue** : la fiche du personnage montre et modifie les répliques de la langue écoutée. Quand vous changez de langue principale, les répliques déjà saisies restent rattachées à leur langue d'origine. Sans réplique dans une langue, *Réplique du perso* dit la phrase type de la voix et vous prévient.

## 5. Bibliothèque de voix

![Bibliothèque](../img/bibliotheque-dark.jpg)

La bibliothèque compte **600 recettes** (hommes, femmes, enfants, animaux, créatures), avec un extrait dans chaque langue de vos projets. Elles sont fabriquées sur votre Mac par le modèle Qwen3-TTS VoiceDesign ; la description de la voix suit la langue calculée, pour éviter un accent étranger.

- Recherche libre (« bourru », « dragon », « enfant »…) et filtres : genre, langue, voix utilisées ou jamais utilisées.
- La fiche de la voix affiche sa recette (sa description), son moteur, ses extraits, les projets qui l'utilisent, et permet un essai sur une phrase libre avec une émotion.
- **Génération de la bibliothèque** lance ou reprend la fabrication, langue par langue. Un seul calcul tourne à la fois, et son état s'affiche en bas de la barre latérale.
- Le panneau **Langues de la bibliothèque** de cet écran montre, pour chaque langue, les extraits prêts et les projets qui s'en servent. Une langue peut être mise en pause et reprise. *Ajouter une langue* calcule une langue pour toute la bibliothèque sans projet ; une langue qu'aucun projet n'utilise peut être libérée (ses extraits et ses écoutes en cache sont supprimés, et pourront être recalculés).

![Langues de la bibliothèque](../img/langues-bibliotheque.jpg)

## 6. Cloner une voix

1. Ouvrez **Cloner une voix**.
2. Choisissez un fichier audio ou vidéo (WAV, MP3, M4A, AIFF…) ou collez un lien web (YouTube et d'autres sites, audio seul).
3. Sélectionnez un extrait de 15 à 25 secondes, où la voix est claire et seule.
4. Vérifiez la transcription automatique, et corrigez-la si besoin.
5. Cochez la case par laquelle vous certifiez avoir le droit d'utiliser cette voix, puis ajoutez-la : elle rejoint la bibliothèque comme une voix normale.

> N'utilisez que des voix dont vous avez le droit : la vôtre, celle d'une personne qui a donné son accord, ou une voix libre de droits.

## 7. Modèles de voix

La page **Modèles TTS** affiche le moteur local et chaque modèle, avec son état (installé, en téléchargement), sa taille et les langues qu'il sait dire. Les modèles sont téléchargés depuis Hugging Face à la demande, avec reprise en cas de coupure.

| Nom dans le guide | Modèle | Taille | Langues | Point fort |
|---|---|---|---|---|
| Créateur de voix | Qwen3-TTS VoiceDesign | 3,1 Go | 10 | Fabrique la bibliothèque à partir des descriptions. |
| Voix naturelle | Qwen3-TTS Base | 3,1 Go | 10 | Polyvalente et rapide, conseillée par défaut. |
| Voix d'acteur | Fish Audio Drama 3 | 22 Go | 13 | La plus vivante et émouvante, plus lente. |
| Voix expressive | Chatterbox multilingue | 2,7 Go | 23 | Très démonstrative, idéale pour l'animation. |
| Voix rapide | OmniVoice | 1,3 Go | 23 | Légère, pour les Mac modestes. |
| Bruitages | Stable Audio 3 Small SFX | 3,5 Go | — | Cris de créatures et d'animaux. |

Le guide ne propose que les modèles adaptés à votre Mac : un modèle est conseillé s'il utilise moins de la moitié de la mémoire, et il n'est plus affiché au-delà de 70 %.

## 8. Créatures et animaux

Un personnage marqué « créature » ou « animal » (par l'import, par l'IA, ou d'après son nom et son rôle) a droit à des outils dédiés :

- **Voix suggérées** : trois voix de la bibliothèque, choisies selon l'espèce (dragon, troll, gobelin, fantôme, robot, chat…).
- **Effets de voix** : trois effets à essayer à l'oreille selon le type de créature, par exemple très grave, grondant, caverneux, aigu, couinant, écho spectral, métallique ou radio. L'effet choisi s'applique aux essais de répliques.
- **Cri** : un bruitage sans paroles, généré par le modèle de bruitages, à rejouer ou à refaire.

L'effet est inscrit dans `casting.json` avec son équivalent ffmpeg (`fx_ffmpeg`), pour que les répliques définitives sonnent comme ce que vous avez choisi.

## 9. Travailler avec un assistant IA

### Avec l'IA que vous utilisez déjà

À l'étape *Préparation* du guide, **Installer dans mes IA** détecte Claude Code, Codex (ChatGPT), Cursor et Claude Desktop, puis y ajoute :
- le **skill mcasting**, des instructions qui apprennent à l'agent à structurer un projet pour un casting voix ;
- le **serveur MCP mcasting**, qui permet à l'agent de piloter l'appli.

Chaque fichier de configuration est sauvegardé avant modification, et rien n'est fait sans votre confirmation. **Copier les instructions pour mon IA** fournit le même mode d'emploi à coller dans n'importe quelle autre IA.

Demandez ensuite simplement à votre agent : *« Importe ce projet dans mCASTING. »* Il lit vos fichiers (script, dialogues, fichiers du jeu), construit la liste des personnages et l'importe. Vous castez à l'oreille dans l'appli, puis l'agent génère les répliques à partir de `casting.json`.

### Avec une IA installée sur votre Mac

Si **Ollama** ou **LM Studio** tourne sur votre Mac, mCASTING le détecte. Il peut alors analyser vos personnages (genre, âge, humain, créature ou animal, et une description de la voix), gratuitement et sans rien envoyer sur Internet. Le casting déjà fait n'est jamais modifié.

## 10. Voix fabriquées ailleurs : serveur réseau et ElevenLabs

### Sur un autre ordinateur

Si un ordinateur de votre réseau fait tourner un serveur de voix compatible OpenAI (mlx-audio server, LocalAI, Kokoro-FastAPI…) :
1. À l'étape *Voix* du guide, choisissez **Sur un autre ordinateur**, saisissez son adresse (par exemple `http://pc-studio.local:8000`) et une clé si le serveur en demande une.
2. Cliquez sur **Tester**.
3. Choisissez entre **Créer la bibliothèque sur ce serveur** (si le serveur sait créer des voix à partir d'une description) et **Importer les voix de ce modèle** (voix toutes prêtes, avec un extrait dans chaque langue de vos projets).

Le mode *Fidèle* (clonage) reste fait sur votre Mac, car ces serveurs ne reçoivent pas d'extraits audio.

### Avec ElevenLabs (payant)

1. Choisissez **Avec un service en ligne**, saisissez votre clé ElevenLabs (rangée dans le Trousseau) et cliquez sur **Vérifier** : le solde de crédits s'affiche.
2. **Importer mes voix ElevenLabs** est gratuit : seuls les extraits de présentation sont téléchargés.
3. Chaque génération avec une voix ElevenLabs affiche d'abord le nombre de caractères et les crédits estimés (environ 0,4 crédit par caractère), et attend votre confirmation.

## 11. Le fichier casting.json

`casting.json` est écrit dans le dossier du projet. Il indique la langue principale (`lang`) et les langues du projet (`languages`), puis, pour chaque personnage :

- la voix choisie (`voice_id`), sa recette, l'interprétation (`style`) ;
- un extrait de la voix par langue (`samples`) et le modèle qui dit les répliques (`acting_model`) ;
- pour une voix clonée, l'extrait et le texte de référence (`ref_audio`, `ref_text`) ;
- les répliques dans les autres langues (`lines_alt`) ;
- pour une créature, le cri (`sfx`) et l'effet (`fx`, `fx_ffmpeg`) ;
- pour une voix de serveur ou d'ElevenLabs, le modèle et la voix distante.

**Règle de génération :** chaque réplique est dite en clonant l'extrait de la voix *dans la langue de la réplique* avec le modèle de jeu. On ne régénère jamais une voix depuis sa description, car le modèle tirerait un nouveau timbre à chaque fois. Le détail du format est dans le [dossier de développement](../pdf/mCASTING-developpement-FR.pdf).

## 12. Serveur MCP

mCASTING contient un serveur MCP (`mcasting-mcp`). La commande exacte pour le déclarer dans votre agent est affichée dans **Réglages › Serveur MCP**, par exemple :

```bash
claude mcp add mcasting -- "/Applications/mCASTING.app/Contents/MacOS/mcasting-mcp"
```

Outils : `get_import_guide`, `import_project`, `export_project`, `list_projects`, `list_languages`, `create_project`, `set_project_languages`, `add_characters`, `list_characters`, `search_voices`, `set_casting`, `preview_voice`, `write_casting`. Les appels reçus s'affichent dans le journal des Réglages. `list_languages` donne les langues possibles pour un projet et celles où toute voix peut être écoutée ; `preview_voice` accepte n'importe laquelle de ces langues.

## 13. Réglages et mises à jour

- **Général** : langue de l'interface (français, anglais, espagnol, italien ; automatique par défaut) et dossier de la bibliothèque.
- **Mises à jour** : mCASTING vérifie chaque jour s'il existe une nouvelle version. Avec « Installer automatiquement », il l'installe et se relance, jamais pendant un calcul. Un bouton lance la recherche à la main.
- **Serveur MCP** : commande à copier, liste des outils, journal des appels.
- La fenêtre s'ouvre toujours centrée, à la dernière taille que vous lui avez donnée.

## 14. Données, confidentialité et droits

- Tout est stocké sur votre Mac, dans `~/Library/Application Support/mCASTING/` : projets, bibliothèque, extraits audio, moteur et modèles.
- Rien n'est envoyé sur Internet, sauf ce que vous déclenchez : téléchargement des modèles depuis Hugging Face, lien web à cloner, serveur de voix que vous avez choisi, ElevenLabs si vous l'utilisez.
- Les clés (serveur, ElevenLabs) sont rangées dans le Trousseau macOS, jamais dans des fichiers.
- Vous êtes responsable des droits sur les voix que vous clonez ou importez. Certains modèles ont leur propre licence : Fish Audio Drama 3, par exemple, demande une mention en cas d'usage commercial.

## 15. Questions fréquentes et dépannage

**La génération est lente.** Un seul calcul tourne à la fois, et le premier essai d'un modèle le charge en mémoire. Choisissez un modèle plus léger (Voix rapide) sur un Mac modeste.

**Un modèle n'apparaît pas dans le guide.** Il demande trop de mémoire pour votre Mac (plus de 70 %). La page Modèles TTS les liste tous.

**Une voix a un accent dans une autre langue.** C'est normal quand la langue écoutée n'est pas une langue du projet : le timbre est cloné depuis un extrait d'une autre langue. Ajoutez cette langue au projet (bouton **＋** de la barre latérale) : la bibliothèque calculera un extrait natif dans cette langue.

**Une langue n'est pas proposée pour un projet.** Les langues d'un projet sont celles du créateur de voix (10). Les autres langues restent disponibles à l'écoute, par clonage, si un modèle installé les parle (page Modèles TTS).

**Mes anciens projets ?** Les projets créés avant la 2.0 s'ouvrent en français + anglais, sans perte.

**Mon agent ne voit pas mCASTING.** Relancez l'étape *Préparation › Installer dans mes IA*, ou déclarez le serveur avec la commande des Réglages, puis redémarrez l'agent.

**Où est écrit casting.json ?** Dans le dossier choisi pour le projet (bouton *Dossier* de l'écran Casting). Sans dossier, le bouton *Écrire casting.json* est désactivé.

**Supprimer un projet efface-t-il mes fichiers ?** Non. Le projet disparaît de mCASTING, mais son dossier et son `casting.json` restent en place.
