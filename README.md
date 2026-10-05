# CMakeUtils

Utilitaires CMake réutilisables : des modules `.cmake` (macros et fonctions) à inclure dans ses projets.

## Prérequis

- CMake 3.13 ou supérieur

## Utilisation

Inclure le point d'entrée `CMakeUtils.cmake`, qui charge tous les modules :

```cmake
include(chemin/vers/CMakeUtils/CMakeUtils.cmake)
```

Ou ajouter le dépôt au `CMAKE_MODULE_PATH` pour l'inclure par son nom :

```cmake
list(APPEND CMAKE_MODULE_PATH "chemin/vers/CMakeUtils")
include(CMakeUtils)
```

Un module peut aussi être inclus seul (`include(chemin/vers/CMakeUtils/target.cmake)`), sans les dossiers par défaut ci-dessous.

### Dossiers par défaut

`CMakeUtils.cmake` définit deux variables de cache (type `STRING`), sans toucher à une valeur déjà définie avant l'inclusion (variable normale ou `-D` en ligne de commande) :

| Variable                 | Défaut    | Rôle                                   |
| ------------------------ | --------- | -------------------------------------- |
| `cmu_public_headers_dir` | `include` | Dossier des en-têtes publics           |
| `cmu_sources_dir`        | `src`     | Dossier des sources et en-têtes privés |

```cmake
set(cmu_public_headers_dir "api")
include(chemin/vers/CMakeUtils/CMakeUtils.cmake)
```

Elles peuvent aussi être modifiées avec `cmake -Dcmu_sources_dir=lib ...`. Les chemins relatifs sont relatifs au `CMakeLists.txt` appelant. Ces variables sont lues à chaque appel de `cmu_add_target` (voir ci-dessous).

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
| `SOURCES`             | Fichiers sources, relatifs à `cmu_sources_dir`                                |
| `INCLUDE_DIRECTORIES` | Transmis à `target_include_directories()`                                     |
| `COMPILE_DEFINITIONS` | Transmis à `target_compile_definitions()`                                     |
| `COMPILE_OPTIONS`     | Transmis à `target_compile_options()`                                         |
| `COMPILE_FEATURES`    | Transmis à `target_compile_features()`                                        |
| `LINK_LIBRARIES`      | Transmis à `target_link_libraries()`                                          |
| `LINK_OPTIONS`        | Transmis à `target_link_options()`                                            |

Les valeurs des six derniers mots-clés sont transmises telles quelles à la commande `target_*` correspondante : la portée (`PUBLIC`, `PRIVATE` ou `INTERFACE`) s'écrit comme pour cette commande, plusieurs portées peuvent être combinées dans une même liste, et elle est obligatoire (sauf pour `LINK_LIBRARIES`, dont la forme sans portée est déconseillée). Un mot-clé peut être répété : ses valeurs s'accumulent.

Les chemins de `SOURCES` relatifs sont préfixés par `cmu_sources_dir` (`SOURCES core.cpp` désigne `src/core.cpp`) ; les chemins absolus et les expressions génératrices (`$<...>`) sont gardés tels quels.

Si les dossiers `cmu_public_headers_dir` et `cmu_sources_dir` existent, ils sont ajoutés automatiquement avant les `INCLUDE_DIRECTORIES` : `cmu_public_headers_dir` en `PUBLIC` (`INTERFACE` pour une target `INTERFACE`) et `cmu_sources_dir` en `PRIVATE` (ignoré pour une target `INTERFACE`).

Exemple :

```cmake
include(chemin/vers/CMakeUtils/CMakeUtils.cmake)

cmu_add_target(
    NAME core
    TYPE STATIC
    SOURCES core.cpp
    COMPILE_DEFINITIONS PUBLIC CORE_VALUE=42
    COMPILE_FEATURES PUBLIC cxx_std_17
)

cmu_add_target(
    NAME app
    TYPE EXECUTABLE
    SOURCES main.cpp
    LINK_LIBRARIES PRIVATE core
)

cmu_add_target(NAME utils TYPE INTERFACE)
```

Un projet complet est disponible dans [exemple/](exemple/CMakeLists.txt).

Remarques :

- Les chemins relatifs (hors `SOURCES`) sont relatifs au `CMakeLists.txt` qui appelle `cmu_add_target`.
- Un argument inconnu, un `NAME` manquant ou un `TYPE` manquant ou invalide arrête la configuration avec un message d'erreur.
- `SOURCES` avec `TYPE INTERFACE` nécessite CMake 3.19.
- `cmu_add_target` est une macro : elle s'exécute dans la portée de l'appelant. Ses variables internes (préfixe `_ADD_TARGET_`) sont supprimées en fin d'appel.
- Une macro réévalue ses arguments : utiliser `/` dans les chemins, un `\` provoque l'erreur `Invalid character escape`.
