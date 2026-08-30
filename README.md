# TENKAI — Prototype pré-alpha jouable

**TENKAI** est un vertical slice **Action RPG 3D** inspiré des sensations de
Naruto Storm / Dragon Ball Z / Genshin Impact, sans reprendre aucun asset ni
personnage sous licence. Cette version 0.6 est un prototype réellement lançable :
le joueur apparaît dans **MONDHOLM — Vallée de la Résonance**.

Le projet est construit pour **Godot 4.4+** et utilise uniquement des assets
procéduraux (meshes, matériaux, particules, audio) donc il se lance directement
depuis le projet sans import de fichiers externes.

## Démarrage rapide

1. Installer [Godot 4.4](https://godotengine.org/) (version standard ou .NET).
2. Ouvrir ce dossier dans Godot (`project.godot`).
3. Cliquer **Play** (ou `F6` si la scène `Main.tscn` est ouverte).
4. Sur le menu principal : **Nouvelle partie**.

Scène de départ : `res://scenes/main/Main.tscn` (défini dans `project.godot`).

## Contrôles par défaut

| Action | Clavier | Manette (extensible) |
| --- | --- | --- |
| Déplacement | WASD / flèches | Stick gauche |
| Sprint | SHIFT | L1/R1 selon mapping |
| Saut | SPACE | A |
| Attaque légère | J | X |
| Attaque lourde | K | Y |
| Compétence | E | R2 |
| Burst / ultimate | R | L2 |
| Garde | G (maintenir) | B |
| Esquive / i-frames | ALT | Stick droit |
| Lock-on | L | Stick gauche (press) |
| Changer de cible | Q / TAB / molette | D-pad |
| Interagir | F | Back / Select |
| Pause | ÉCHAP | Start |
| Sauvegarder | F5 | n/a |
| Recharger | F9 | n/a |
| Console debug | F1 | n/a |

La souris contrôle la caméra ; la molette zoome.

## Console debug (F1)

Vous pouvez taper `help` pour la liste, puis :

- `tp x y z`, `heal`, `spawn warrior|brute|archer|corrupted|elite`
- `boss`, `boss_reset`, `complete_mission`, `fps`, `hitboxes`
- `save`, `load`, `quit`

## Contenu jouable

- Contrôleur **Kaelis** : marche, course, saut, esquive avec i-frames, garde,
  Perfect Guard (stun de l'attaquant), combos légers, attaque lourde, aérienne,
  compétence, burst.
- **Lock-on** avec cibles prioritaires, changement de cible et caméra de suivi.
- Cinq archétypes d'ennemis : guerrier, brute, archer, corrompu, élite.
- Boss **VAELITH** en 4 phases (mêlée, distance/zones, combo, éveil).
- Missions : Prologue → Les Totems → Les Éclats → Le Moulin → L'Éveil → Épilogue.
- Sauvegarde/chargement (`user://tenkai_save.json`) via console debug.
- UI : HP, endurance, énergie, burst, barre boss, mission, dialogue, pause, mort.
- VFX procéduraux : impact, spark, hit-stop, camera shake, dash, burst, ring.
- Audio procédural placeholder et musique par contexte.
- QA headless dans `res://scenes/main/AutoTest.tscn`.

## Tests statiques disponibles

```bash
godot --headless --path . --scene res://scenes/main/AutoTest.tscn
```

Le script `AutoTester.gd` vérifie les scènes requises, les actions InputMap,
les ressources `res://`, les `class_name` et quelques références.
Avec `gdtoolkit` :

```bash
pip install gdtoolkit --break-system-packages
gdformat .
gdlint .
```

## Arborescence principale

```
scenes/main/Main.tscn          Point d'entrée
scenes/player/Player.tscn      Kaelis
scenes/enemies/...             Ennemis + projectiles
scenes/boss/Boss.tscn          Boss
scripts/player/                Player, Combat, Targeting, Camera
scripts/world/                 Génération Mondholm, totems, missions, pickups
scripts/boss/                  Boss + hazards
scripts/core/                  Autoloads, save, missions, audio, VFX, QA
scripts/ui/                    HUD / MainMenu
```
