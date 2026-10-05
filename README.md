# CMakeUtils

Utilitaires CMake réutilisables : des modules `.cmake` (macros et fonctions) à inclure dans ses projets.

## Prérequis

- CMake 3.13 ou supérieur

## Utilisation

Inclure directement un module :

```cmake
include(chemin/vers/CMakeUtils/target.cmake)
```

Ou ajouter le dépôt au `CMAKE_MODULE_PATH` pour inclure les modules par leur nom :

```cmake
list(APPEND CMAKE_MODULE_PATH "chemin/vers/CMakeUtils")
include(target)
```

## Modules

### target.cmake

#### `cmu_add_target`

Crée une target (exécutable ou bibliothèque) et lui applique ses propriétés en un seul appel.

```cmake
cmu_add_target(
    NAME <nom>
    TYPE <EXECUTABLE|STATIC|SHARED|MODULE|OBJECT|INTERFACE>
    [SOURCES <fichier>...]
    [INCLUDE_DIRECTORIES <portée> <dossier>...]
    [COMPILE_DEFINITIONS <portée> <définition>...]
    [COMPILE_OPTIONS <portée> <option>...]
    [COMPILE_FEATURES <portée> <feature>...]
    [LINK_LIBRARIES <portée> <bibliothèque>...]
    [LINK_OPTIONS <portée> <option>...]
)
```

| Mot-clé               | Rôle                                                                          |
| --------------------- | ----------------------------------------------------------------------------- |
| `NAME`                | Nom de la target (obligatoire)                                                |
| `TYPE`                | `EXECUTABLE` → `add_executable()`, les autres → `add_library()` (obligatoire) |
| `SOURCES`             | Fichiers sources de la target                                                 |
| `INCLUDE_DIRECTORIES` | Transmis à `target_include_directories()`                                     |
| `COMPILE_DEFINITIONS` | Transmis à `target_compile_definitions()`                                     |
| `COMPILE_OPTIONS`     | Transmis à `target_compile_options()`                                         |
| `COMPILE_FEATURES`    | Transmis à `target_compile_features()`                                        |
| `LINK_LIBRARIES`      | Transmis à `target_link_libraries()`                                          |
| `LINK_OPTIONS`        | Transmis à `target_link_options()`                                            |

Les valeurs des six derniers mots-clés sont transmises telles quelles à la commande `target_*` correspondante : la portée (`PUBLIC`, `PRIVATE` ou `INTERFACE`) s'écrit comme pour cette commande, plusieurs portées peuvent être combinées dans une même liste, et elle est obligatoire (sauf pour `LINK_LIBRARIES`, dont la forme sans portée est déconseillée). Un mot-clé peut être répété : ses valeurs s'accumulent.

Exemple :

```cmake
include(chemin/vers/CMakeUtils/target.cmake)

cmu_add_target(
    NAME core
    TYPE STATIC
    SOURCES src/core.cpp
    INCLUDE_DIRECTORIES PUBLIC include PRIVATE src
    COMPILE_DEFINITIONS PUBLIC CORE_VALUE=42
    COMPILE_FEATURES PUBLIC cxx_std_17
)

cmu_add_target(
    NAME app
    TYPE EXECUTABLE
    SOURCES src/main.cpp
    LINK_LIBRARIES PRIVATE core
)

cmu_add_target(NAME utils TYPE INTERFACE INCLUDE_DIRECTORIES INTERFACE include)
```

Un projet complet est disponible dans [exemple/](exemple/CMakeLists.txt).

Remarques :

- Les chemins relatifs sont relatifs au `CMakeLists.txt` qui appelle `cmu_add_target`.
- Un argument inconnu, un `NAME` manquant ou un `TYPE` manquant ou invalide arrête la configuration avec un message d'erreur.
- `SOURCES` avec `TYPE INTERFACE` nécessite CMake 3.19.
- `cmu_add_target` est une macro : elle s'exécute dans la portée de l'appelant. Ses variables internes (préfixe `_ADD_TARGET_`) sont supprimées en fin d'appel.
- Une macro réévalue ses arguments : utiliser `/` dans les chemins, un `\` provoque l'erreur `Invalid character escape`.
