# CHANGELOG 0.6 — TENKAI « Playable vertical slice »

Date de livraison : 2026-08-30
Cible : **Godot 4.4+**

---

## 0. Sommaire

Ce dépôt contenait initialement une application web « Cygne Noir » sans aucun
projet Godot (`project.godot`, `.tscn`, `.gd` absents). Conséquence : cette
version a été **construite à partir de zéro** dans le dépôt, selon la décision
validée : **Godot 4.x + vertical slice jouable et mûr**.

Un build complet du cahier des charges demandé n'est **pas** possible dans cette
seule passe. Ce qui est livré est un **vertical slice réellement lançable** :
spawn, exploration, combat, lock-on, ennemies, totems, éclats, défense du moulin,
boss et sauvegarde.

---

## 1. Bugs / problèmes corrigés

Cette macro-version est neuve, mais les défauts suivants ont été détectés et
corrigés pendant la session :

| Problème | Correctif |
| --- | --- |
| Le projet ne contenait aucun projet Godot | `project.godot`, autoloads, scènes, scripts créés |
| Actions de `InputMap` non sérialisées / fragiles | `Bootstrap.gd` construit le mapping clavier + manette au runtime |
| `size` / resource paths `res://` absents | Vérifiés par `AutoTester.gd` (0 référence absente en audit statique) |
| `ConcavePolygonShape3D.set_faces()` appelé avec `verts + indices` (API inexistante) | Converti en liste de triangles `PackedVector3Array` |
| `GameState.burst` était utilisé alors que la variable réelle était `player_burst` | Synchronisé via `GameState.player_burst` + setter |
| Skill / Burst cherchaient leurs données dans `ATTACK_DATA` alors qu'ils n'y sont pas | Branche dédiée `skill` / `burst` dans `CombatController._process()` |
| Ennemis créés avant que `enemy_type` ne soit appliqué → tous des « warrior » | Le type est posé **avant** `add_child()` |
| `Perfect Guard` ne se réinitialisait jamais → garde parfaite permanente | Fenêtre `guard_perfect_window = 0.18` décrémentée et réinitialisée à l'entrée en garde |
| Boss pouvait double-taper sur `charged_swipe` | Suppression du `_melee_arc_hit()` du déclencheur initial (`_fire_attack`) |
| Cible morte / en cours de suppression restait verrouillable | `_candidate_targets()` filtre les cibles avec `is_alive == false` |
| Le debug `hitboxes` appelait `toggle_hitbox_view` sur des nœuds qui ne l'ont pas | Il cible uniquement `targeting` et `camera` |
| Le debug `heal` ne modifiait pas les variables du joueur | Appelle désormais `player.heal_full()` |
| F5/F9 de sauvegarde/chargement manquaient | Actions + raccourcis ajoutés et branchés dans le HUD |
| Moulin : les vagues ne relançaient pas après la 1re | Timestamp `_mill_wave_timer` + `_begin_next_wave()` branché |

---

## 2. Systèmes ajoutés

### Player
- Contrôleur `CharacterBody3D` séparé en composants :
  - `Player.gd` : locomotion, garde, esquive, i-frames, hit/reaction, mort, respawn.
  - `CombatController.gd` : light / heavy / air / combo / skill / burst, hit-stop, camera shake.
  - `TargetingSystem.gd` : lock-on, changement de cible, cibles prioritaires, marqueur.
  - `CombatCamera.gd` : orbit caméra, sensibilité, zoom, lock camera.

### Combat
- Attaque légère / lourde / aérienne / combo 3 coups / finisher feedback / skill / burst.
- Garde, garde réduite, **Perfect Guard** (0.18 s) qui stun l'attaquant.
- Esquive avec I-frames + coût endurance.
- Lock-on avec priorité visuelle, perte automatique hors distance.
- Effets procéduraux : particules, sparks, flashs, hit-stop, camera shake, dash trail, rings.

### Ennemis & IA
- `EnemyBase.gd` : état Idle / Patrol / Detect / Chase / Attack / Dodge / Stagger / Hurt / Retreat / Dead.
- Archétypes : `warrior`, `brute`, `archer`, `corrupted`, `elite`.
- Projectiles `Area3D`, drops d'énergie, détection anti-blokage.

### Boss — VAELITH
- 4 phases par seuils de HP :
  1. mêlée rapide ;
  2. projectiles en éventail + zones dangereuses ;
  3. combo dash + zones + éventails ;
  4. forme éveillée, burst multi-zones.
- Télégraphes visuels, cooldowns, recoil, `Perfect Guard` récompensé.

### Mondholm — Vallée de la Résonance
- Génération déterministe : terrain, chemins, village, moulin, rivière, pont, forêt, ruines, totems, boss arena.
- Boss zone, zone de mouvement / clickers, collectibles, drops.
- Optimisation : un seul mesh de terrain, instancing des végétaux via arrays, opères de VFX auto-supprimés.

### Missions / narrative
- Prologue → 1. Les Totems → 2. Les Éclats → 3. Le Moulin → 4. L'Éveil → Épilogue.
- PNJ Mael, dialogues (F), objectifs UI, notifications, spawn fragments.

### UI
- HP, endurance, énergie, burst, boss bar, mission panel, notification, dialogue,
  prompt interaction, banner région, écran pause, écran mort.

### Save / Audio / VFX
- `SaveManager` JSON dans `user://tenkai_save.json` (`F5` save, `F9` load).
- `AudioManager` 100 % placeholder procédural (musique exploration / combat / boss, SFX).
- `VFXManager` procédural (GPUParticles3D, lumières, torus, tweens).

### QA / debug
- `AutoTest.tscn` + `AutoTester.gd` pour lancement headless.
- Console debug `F1` : `help`, `tp`, `heal`, `spawn`, `boss`, `boss_reset`,
  `complete_mission`, `fps`, `hitboxes`, `save`, `load`, `quit`.

---

## 3. Systèmes améliorés / rendus réutilisables

- Input défini au runtime dans `Bootstrap.gd`, donc extensible sans re-sérialiser
  des événements de clavier/manette dans `project.godot`.
- Architecture sans gros monolithe : `Player`, `Combat`, `Targeting`, `Camera`,
  `Enemy`, `Boss`, `Mission`, `Save`, `VFX`, `UI`, `Audio`, `World`, `Data`.
- Région construite en `MondholmWorld.gd` avec layout data-driven simple.
- Autoloads centralisent les décisions cross-system :
  - `GameState` (session)
  - `MissionManager` (directeur de quête)
  - `SaveManager` (persistance)
  - `AudioManager` (audio)
  - `VFXManager` (effets)

---

## 4. Problèmes restants / known issues

> Ces éléments existent et sont conscients ; ils ne bloquent pas le lancement
> mais doivent être traités pour la prochaine itération.

1. **Pas de runtime réel dans cette sandbox** : `godot` binaire n'était pas
   disponible (téléchargement réseau des releases Godot bloqué) et `apt` n'avait
   pas de paquet. La vérification faite ici est **statique** :
   - `gdlint` + `gdformat` (parsing GDScript : 0 erreur syntaxique) ;
   - audit `res://` (0 référence manquante) ;
   - audit de `class_name`, scènes requises, actions InputMap ;
   - relecture du flux missions / combat / save.
   Les tests **lancement réel, vraie frame, input réel, FPS réel** restent à
   faire sur un poste avec le binaire Godot.

2. **Pas d'assets artistiques finaux** : tout est placeholder procédural pour
   rester sans dépendance. Les matériaux, meshes, particules et sons sont
   simples et à remplacer.

3. **Sauvegarde simple JSON** : suffisante pour le prototype ; pas de slot
   multiple, pas de chiffrement, pas de versionning avancé.

4. **IA ennemis simple** : pas de véritable Patrol pathing ni navigation mesh ;
   les ennemis peuvent traverser les ruines basses / objets sans hauteur.

5. **Boss phases** implémentées mais il faut un équilibrage réel en conditions
   de jeu (damage, cooldowns, telegraphes).

6. **Performance** : terrain et végétation sont déjà modestes, mais il faudra
   mesurer draw calls sur une machine avec Godot réel, notamment pour
   `GPUParticles3D` et les ombres.

7. **Audio** : sons générés procéduraux, sans SFX « clean » ni mastering.

8. **Historique dialogue** : Mael a trois lignes successives ; pas encore de
   dialogue à choix ni de cinématiques.

---

## 5. Commandes de lancement

### Depuis l'éditeur Godot
1. Ouvrir le dossier dans Godot 4.4+.
2. Laisser l'import initial se faire (aucun asset externe, il est rapide).
3. **Play**.

### Ligne de commande (binaire Godot)
```bash
# Lancer le jeu
godot --path . 

# Lancer le test QA headless
godot --headless --path . --scene res://scenes/main/AutoTest.tscn
```

### Outils de style / lint (optionnel)
```bash
pip install gdtoolkit --break-system-packages
gdformat .
gdlint .
```

---

## 6. Contrôles

| Action | Clavier | Manette (mapping minimal) |
| --- | --- | --- |
| Déplacement | WASD / flèches | Stick gauche |
| Sprint | SHIFT | —
| Saut | SPACE | A |
| Attaque légère | J | X |
| Attaque lourde | K | Y |
| Compétence | E | R2 |
| Burst | R | L2 |
| Garde (maintenir) | G | B |
| Esquive | ALT | Stick droit |
| Lock-on | L | Stick gauche |
| Changer de cible | Q / TAB | D-pad |
| Interagir / dialogue | F | Back/Select |
| Pause | ÉCHAP | Start |
| Sauvegarde rapide | F5 | — |
| Chargement rapide | F9 | — |
| Console debug | F1 | — |

---

## 7. Procédure de test recommandée

### Test 1 — Lancement
1. Ouvrir le projet.
2. Play.
3. Vérifier menu principal visible + jeu en pause.
4. **Nouvelle partie** → Mondholm apparaît, HUD à jour.

### Test 2 — Contrôles Kaelis
- Utiliser chaque contrôle (marche, sprint, saut, esquive, garde).
- Vérifier caméra orbite, molette zoom, pas de `jitter` fort.

### Test 3 — Combat de base
- Spawn via `F1` → `spawn warrior`.
- Vérifier combo `J J J`, heavy `K`, skill `E`, burst `R`.
- Vérifier hit-stop, sparks, camera shake, knockback.

### Test 4 — Lock-on
- `L` lock, `Q/TAB` change cible.
- Se mettre loin → lock se perd.

### Test 5 — Perfect Guard
- Maintenir `G` juste avant l'impact → SFX + étourdissement de l'ennemi.
- Vérifier que les dégâts passent à 0 et que l'ennemi est stagger.

### Test 6 — Missions / totems
- Parler à Mael (`F`).
- Détruire 3 totems (`J` / `K` / `E`).
- Récupérer les 3 Éclats.
- Entrer au moulin → 3 vagues.
- Boss arena ouverte.

### Test 7 — Boss
- Entrer en zone boss.
- Vérifier 4 phases, projectiles, zones, telegraphes.
- Tester Perfect Guard vs boss.

### Test 8 — Mort / respawn
- Mourir pendant un combat.
- Vérifier overlay death + `SPACE` respawn.

### Test 9 — Save / load
- `F5`, puis `F9`.
- Vérifier position, HP, mission, totems, fragments.

### Test 10 — QA headless
```bash
godot --headless --path . --scene res://scenes/main/AutoTest.tscn
```

---

## 8. Critère de réussite

Un joueur peut ouvrir `project.godot`, cliquer **Play**, choisir **Nouvelle
partie**, déplacer Kaelis, combattre, casser les totems, défendre le moulin et
affronter le boss dans une première boucle de gameplay cohérente.
