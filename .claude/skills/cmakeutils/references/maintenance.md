# Faire évoluer CMakeUtils

À lire avant de modifier `CMakeUtils.cmake`, `Utils/` ou `Template/`.

## Carte du dépôt

| Fichier                                  | Rôle                                                                                   |
| ---------------------------------------- | -------------------------------------------------------------------------------------- |
| `CMakeUtils.cmake`                       | Point d'entrée : valeurs par défaut des variables `cmu_*`, règles C++, inclusion des modules |
| `Utils/qt.cmake`                         | `QTDIR`, détection de Qt dans le graphe de liens, `windeployqt` (compilation et installation) |
| `Utils/target.cmake`                     | `cmu_add_target` et ses raccourcis                                                     |
| `Utils/package.cmake`                    | Installation automatique, `cmu_install_targets`, `cmu_add_package`, target `cmu_package` |
| `Utils/Package*Config.cmake.in`          | Modèles des fichiers `Config.cmake` (paquet, et paquet à composants du mode `TARGET`)  |
| `Template/target_*.in`                   | Modèles des fichiers d'informations de chaque target (`_info.h`, `_info.cpp`, `_info.rc`) ; l'en-tête d'export vient de `generate_export_header` |
| `exemple/`                               | Projet de démonstration ; c'est aussi le banc d'essai                                  |
| `README.md`                              | La documentation, en français                                                          |

## Conventions

- **Noms.** API publique en `cmu_` ; fonctions internes en `_cmu_` ; variables réglables en minuscules `cmu_*` ; propriétés globales en `CMU_*` ; variables internes de `cmu_add_target` en `_ADD_TARGET_*`.
- **Langues.** Commentaires du code et textes de `message()` en anglais ; README et messages de commit en français.
- **Commentaires.** Courts, et ils disent pourquoi (la contrainte de CMake qui impose la forme du code), pas ce que fait la ligne.
- **Variables réglables.** Entrée de cache protégée par `if(NOT DEFINED ...)`, pour qu'une variable normale définie avant l'inclusion ou un `-D` l'emporte. Chacune a sa ligne dans un tableau du README.
- **Arguments.** `cmake_parse_arguments`, puis `FATAL_ERROR` sur tout argument inconnu ou valeur invalide, avec le nom de la commande dans le message.
- **Version de CMake.** Le socle est 3.13. Ce qui demande plus récent est gardé par `CMAKE_VERSION VERSION_LESS`, se dégrade proprement (message `STATUS` ou fonction absente) et est signalé dans le README (« Nécessite CMake 3.19 »).
- **Commits.** `<module>: <Description>` en français (`target: Ajout de ...`, `package: Ajout ...`), README mis à jour dans le même commit.

## Mécanismes à connaître

Ce sont les points où une modification anodine casse quelque chose plus loin.

- **`cmu_add_target` est une macro.** Elle s'exécute dans la portée de l'appelant : toute variable temporaire prend le préfixe `_ADD_TARGET_`, que le nettoyage final supprime par expression régulière. Un `return()` y ferait quitter le `CMakeLists.txt` appelant. Les arguments sont réévalués, d'où l'interdiction du `\`.
- **Les modèles lisent ces variables.** `configure_file(... @ONLY)` remplace `@_ADD_TARGET_X@` : une variable utilisée par un modèle doit être définie avant l'appel, et renommer l'une impose de renommer l'autre.
- **`CMAKE_CURRENT_LIST_DIR` dans une fonction est celui de l'appelant.** Les chemins des modèles sont donc capturés à l'inclusion du module (`_CMU_TEMPLATE_DIR`, `_CMU_PACKAGE_CONFIG_TEMPLATE`).
- **État partagé entre modules : propriétés globales.** `CMU_PACKAGE_TARGETS` et `CMU_PACKAGE_HEADERS` (remplies par `cmu_add_target`, lues par l'installation automatique), `CMU_HEADERS_<target>`, `CMU_GENERATED_HEADER_<target>` (en-tête public généré, à installer), `CMU_PACKAGE_DONE` (un appel explicite a remplacé l'automatique), `CMU_FIND_PACKAGE_CALLS`.
- **Appels différés.** `cmake_language(DEFER)` lance `_cmu_package_finalize` à la fin du dossier qui a inclus CMakeUtils, et `_cmu_qt_deploy` à la fin du dossier de chaque exécutable, quand ses dépendances sont déclarées. Le nom de la target y est figé par `cmake_language(EVAL CODE ...)`, car les arguments différés sont évalués après le nettoyage de la macro.
- **`find_package` est redéfini** pour mémoriser les appels ; `_find_package` est l'original. Désactivé si un autre outil l'a déjà redéfini (vcpkg), sinon la récursion est infinie.
- **Toute règle `install()` porte `COMPONENT ${_CMU_PACKAGE_COMPONENT}`.** La target `cmu_package` copie le résultat avec `cmake --install --component cmu_package` : une règle sans ce composant est installée par `cmake --install` mais absente de `<build>/package`.
- **Rien de l'arbre de sources ou de build dans une propriété exportée.** Passer par `$<BUILD_INTERFACE:...>`, comme pour `include/` et les sources des targets `INTERFACE` ; le chemin installé est ajouté dans le `Config.cmake` généré.
- **Deux dossiers générés par target**, à côté des fichiers générés par Qt. `<NAME>_autogen/cmu/include` est privé ; `<NAME>_autogen/cmu/public` est `PUBLIC` et son contenu est installé.
- **Les fichiers générés sont rangés pour l'IDE.** Ceux ajoutés à `_ADD_TARGET_AUTOGEN_FILES` apparaissent dans le dossier `autogen\cmu` du projet Visual Studio (`source_group`) ; ceux de Qt sont rangés par nom dans `autogen\moc`, `autogen\rcc` et `autogen\uic`.

## Ajouter une fonctionnalité

Un mot-clé de `cmu_add_target` :

1. l'ajouter à la liste voulue de `cmake_parse_arguments` (valeur unique ou liste) ;
2. le traiter, en variables `_ADD_TARGET_*` ;
3. le README : synopsis, tableau des mots-clés, et une remarque s'il a une limite ;
4. `exemple/` s'il mérite d'être montré.

Un fichier généré : le modèle dans `Template/` avec sa ligne « Generated by CMakeUtils ... do not edit », `configure_file(... @ONLY)` vers le dossier privé ou public, l'ajout à `_ADD_TARGET_AUTOGEN_FILES` pour qu'il soit rangé dans l'IDE, et pour un en-tête public la propriété `CMU_GENERATED_HEADER_<target>` afin qu'il soit installé.

## Vérifier

Il n'y a pas de suite de tests : `exemple/` en tient lieu. Il lui faut Qt 6, trouvé par `QTDIR`. `build/` et `install/` à la racine sont ignorés par git.

```bash
cmake -S exemple -B build
```

```bash
cmake --build build --config Debug
```

```bash
cmake --install build --config Debug
```

```bash
./build/bin/Debug/MyQtApp.exe
```

À contrôler : aucune alerte à la configuration, la sortie de `MyQtApp` (valeurs des bibliothèques et bloc `about`), et les arborescences `build/package` et `install/`, qui doivent correspondre à celles du README.

`exemple/` ne couvre que le chemin nominal du mode `TARGET`. Selon la modification :

- mode `PACKAGE` : un second dossier de build (`cmake -S exemple -B build-pkg -Dcmu_install_mode=PACKAGE`), le mode étant en cache ;
- installation ou export : un petit projet tiers qui fait `find_package` sur le résultat, avec et sans `COMPONENTS` ;
- message d'erreur ou cas limite : un projet jetable hors du dépôt, pour ne pas encombrer `exemple/`.

## Limite connue

En mode `TARGET`, `cmu_install_targets` ne reconnaît les dépendances entre composants que par le nom simple de la target. Une target liée par son alias (`LINK_LIBRARIES PUBLIC MonProjet::Core`) n'est pas chargée par le `Config.cmake` du composant qui en dépend, et `find_package(... COMPONENTS ...)` échoue chez l'utilisateur. Si ce point est corrigé, retirer le piège correspondant de `SKILL.md`.
