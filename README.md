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

`CMakeUtils.cmake` doit être inclus après `project()` : sinon la configuration s'arrête avec l'erreur `CMakeUtils must be included after project()`.

Un module peut aussi être inclus seul (`include(chemin/vers/CMakeUtils/Utils/target.cmake)`), sans les dossiers par défaut ci-dessous.

### Dossiers par défaut

`CMakeUtils.cmake` définit quatre variables de cache (type `STRING`), sans toucher à une valeur déjà définie avant l'inclusion (variable normale ou `-D` en ligne de commande) :

| Variable                 | Défaut    | Rôle                                                    |
| ------------------------ | --------- | ------------------------------------------------------- |
| `cmu_public_headers_dir` | `include` | Dossier des en-têtes publics                            |
| `cmu_sources_dir`        | `src`     | Dossier des sources et en-têtes privés                  |
| `cmu_sources_extension`  | `cpp`     | Extension(s) des sources (liste, ex. `cpp;cc`)          |
| `cmu_headers_extension`  | `h`       | Extension(s) des en-têtes (liste, ex. `h;hpp`)          |

```cmake
set(cmu_public_headers_dir "api")
set(cmu_headers_extension "h;hpp")
include(chemin/vers/CMakeUtils/CMakeUtils.cmake)
```

Elles peuvent aussi être modifiées avec `cmake -Dcmu_sources_dir=lib ...`. Les chemins relatifs sont relatifs au `CMakeLists.txt` appelant. Ces variables sont lues à chaque appel de `cmu_add_target` (voir ci-dessous). Une extension vide désactive la recherche automatique correspondante.

### C++ récent

`CMakeUtils.cmake` applique ces règles aux targets créées après son inclusion (dans le dossier courant et ses sous-dossiers) :

| Variable                      | Valeur                    | Effet                                       |
| ----------------------------- | ------------------------- | ------------------------------------------- |
| `CMAKE_CXX_STANDARD`          | le plus récent supporté   | Compile avec le dernier standard C++ du compilateur |
| `CMAKE_CXX_STANDARD_REQUIRED` | `ON`                      | Erreur si le compilateur ne le supporte pas |
| `CMAKE_CXX_EXTENSIONS`        | `OFF`                     | Standard pur (`-std=c++NN`, pas `gnu++NN`)  |

Le standard retenu est le plus récent parmi 26 et 23 que CMake reconnaît pour le compilateur (`CMAKE_CXX_COMPILE_FEATURES`), sinon 20. Avec MSVC 19.51 et CMake 4.4, c'est C++23 (`/std:c++latest`).

Une variable déjà définie avant l'inclusion (ou avec `-D`) est conservée, par exemple `-DCMAKE_CXX_STANDARD=20`.

## Modules

### target.cmake

#### `cmu_add_target`

Crée une target (exécutable ou bibliothèque) et lui applique ses propriétés en un seul appel.

```cmake
cmu_add_target(
    NAME <nom>
    TYPE <EXECUTABLE|STATIC|SHARED|MODULE|OBJECT|INTERFACE>
    [SHARED_EXTENSION <extension>]
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
| `SHARED_EXTENSION`    | Extension du fichier d'une bibliothèque `SHARED`, avec ou sans point (`plugin`, `.plugin`) ; sans effet, avec un avertissement, pour les autres types |
| `SOURCES`             | Fichiers sources supplémentaires, relatifs à `cmu_sources_dir`                |
| `INCLUDE_DIRECTORIES` | Transmis à `target_include_directories()`                                     |
| `COMPILE_DEFINITIONS` | Transmis à `target_compile_definitions()`                                     |
| `COMPILE_OPTIONS`     | Transmis à `target_compile_options()`                                         |
| `COMPILE_FEATURES`    | Transmis à `target_compile_features()`                                        |
| `LINK_LIBRARIES`      | Transmis à `target_link_libraries()`                                          |
| `LINK_OPTIONS`        | Transmis à `target_link_options()`                                            |

Les valeurs des six derniers mots-clés sont transmises telles quelles à la commande `target_*` correspondante : la portée (`PUBLIC`, `PRIVATE` ou `INTERFACE`) s'écrit comme pour cette commande, plusieurs portées peuvent être combinées dans une même liste, et elle est obligatoire (sauf pour `LINK_LIBRARIES`, dont la forme sans portée est déconseillée). Un mot-clé peut être répété : ses valeurs s'accumulent.

Les chemins de `SOURCES` relatifs sont préfixés par `cmu_sources_dir` (`SOURCES core.cpp` désigne `src/core.cpp`) ; les chemins absolus et les expressions génératrices (`$<...>`) sont gardés tels quels.

La target est remplie automatiquement (recherche récursive, sans doublons avec `SOURCES`) :

- tous les fichiers `*.<cmu_sources_extension>` de `cmu_sources_dir` (sauf pour une target `INTERFACE`) ;
- tous les fichiers `*.<cmu_headers_extension>` de `cmu_public_headers_dir` (pour une target `INTERFACE`, uniquement avec CMake 3.19 ou supérieur).

La recherche utilise `CONFIGURE_DEPENDS` : un fichier ajouté ou supprimé est pris en compte à la compilation suivante. Elle prend tout le dossier : une seule target par couple `cmu_sources_dir` / `cmu_public_headers_dir`, soit un `CMakeLists.txt` par target.

Si les dossiers `cmu_public_headers_dir` et `cmu_sources_dir` existent, ils sont ajoutés automatiquement avant les `INCLUDE_DIRECTORIES` : `cmu_public_headers_dir` en `PUBLIC` (`INTERFACE` pour une target `INTERFACE`) et `cmu_sources_dir` en `PRIVATE` (ignoré pour une target `INTERFACE`).

Exemple, avec un `CMakeLists.txt` par target (voir [exemple/](exemple/CMakeLists.txt)) :

```
exemple/
├── CMakeLists.txt
├── MyStaticLib/   include/MyStaticLib.h, src/MyStaticLib.cpp
├── MySharedLib/   include/MySharedLib.h, src/MySharedLib.cpp
├── MyApp/         src/main.cpp
└── MyQtApp/       src/main.cpp
```

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(exemple LANGUAGES CXX)

include(chemin/vers/CMakeUtils/CMakeUtils.cmake)

find_package(Qt6 REQUIRED COMPONENTS Core)

# Exécutables et DLL côte à côte : MySharedLib.dll est trouvée au lancement
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_subdirectory(MyStaticLib)
add_subdirectory(MySharedLib)
add_subdirectory(MyApp)
add_subdirectory(MyQtApp)
```

```cmake
# MyStaticLib/CMakeLists.txt : bibliothèque statique
cmu_add_static_library(
    NAME MyStaticLib
    COMPILE_DEFINITIONS PRIVATE MYSTATICLIB_VALUE=1
)
```

```cmake
# MySharedLib/CMakeLists.txt : bibliothèque partagée (MYSHAREDLIB_BUILD fait exporter les symboles)
cmu_add_shared_library(
    NAME MySharedLib
    COMPILE_DEFINITIONS PRIVATE MYSHAREDLIB_BUILD
)
```

```cmake
# MyApp/CMakeLists.txt : exécutable utilisant les deux bibliothèques
cmu_add_executable(
    NAME MyApp
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib
)
```

```cmake
# MyQtApp/CMakeLists.txt : idem, plus Qt Core (windeployqt est lancé après la compilation)
cmu_add_executable(
    NAME MyQtApp
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib Qt6::Core
)
```

Ces macros sont des raccourcis de `cmu_add_target` avec un `TYPE` fixé ; elles acceptent les mêmes mots-clés, sauf `TYPE` :

| Macro                        | Équivaut à `TYPE` |
| ---------------------------- | ----------------- |
| `cmu_add_executable`         | `EXECUTABLE`      |
| `cmu_add_static_library`     | `STATIC`          |
| `cmu_add_shared_library`     | `SHARED`          |
| `cmu_add_interface_library`  | `INTERFACE`       |
| `cmu_add_object_library`     | `OBJECT`          |

L'exemple dépend de Qt 6 (CMake 3.16 minimum), trouvé grâce à la variable d'environnement `QTDIR` (voir [qt.cmake](#qtcmake)) ; sinon, indiquer son emplacement avec `-DCMAKE_PREFIX_PATH`, par exemple `cmake -S exemple -B build -DCMAKE_PREFIX_PATH=C:/Qt/6.11.2/msvc2022_64`.

Remarques :

- Les chemins relatifs (hors `SOURCES`) sont relatifs au `CMakeLists.txt` qui appelle `cmu_add_target`.
- Un argument inconnu, un `NAME` manquant ou un `TYPE` manquant ou invalide arrête la configuration avec un message d'erreur.
- `SOURCES` avec `TYPE INTERFACE` nécessite CMake 3.19.
- `cmu_add_target` est une macro : elle s'exécute dans la portée de l'appelant. Ses variables internes (préfixe `_ADD_TARGET_`) sont supprimées en fin d'appel.
- Une macro réévalue ses arguments : utiliser `/` dans les chemins, un `\` provoque l'erreur `Invalid character escape`.

### qt.cmake

Ajoute le contenu de la variable d'environnement `QTDIR` (par exemple `C:\Qt\6.11.2\msvc2022_64`) à `CMAKE_PREFIX_PATH`, ce qui permet à `find_package(Qt6 ...)` de trouver Qt sans `-DCMAKE_PREFIX_PATH`.

- Chargé automatiquement par `CMakeUtils.cmake`, ou inclus seul : `include(chemin/vers/CMakeUtils/Utils/qt.cmake)`.
- Le chemin est ajouté à la fin de `CMAKE_PREFIX_PATH` : un chemin déjà présent est prioritaire, et il n'est pas ajouté deux fois.
- Sans effet si `QTDIR` n'est pas définie ou ne désigne pas un dossier existant.
- Doit être inclus avant `find_package(Qt6 ...)`.
