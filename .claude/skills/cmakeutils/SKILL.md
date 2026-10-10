---
name: cmakeutils
description: "Utiliser et faire évoluer CMakeUtils, les modules CMake cmu_* de ce dépôt (cmu_add_target, cmu_add_executable, cmu_add_static_library, cmu_add_shared_library, cmu_add_interface_library, cmu_add_package, cmu_install_targets, variables cmu_*). À consulter avant d'écrire du CMake dès qu'un projet inclut CMakeUtils.cmake ou qu'un CMakeLists.txt contient un appel cmu_*, même si la demande ne nomme pas CMakeUtils. Couvre : ajouter ou modifier une bibliothèque ou un exécutable, lier Qt, exporter les symboles d'une DLL, installer ou empaqueter pour find_package, diagnostiquer une erreur de configuration ou de génération. À consulter aussi pour modifier les modules eux-mêmes (Utils/*.cmake, Template/*.in, README)."
---

# CMakeUtils

CMakeUtils remplace le CMake répétitif par un appel déclaratif par target. `cmu_add_target` et ses raccourcis créent la target, trouvent ses fichiers, génèrent ses en-têtes d'export et d'informations, puis l'installent et l'exportent pour `find_package`. Presque tout ce qu'on écrit d'habitude à la main est déjà fait : le travail consiste à ranger les fichiers au bon endroit et à ne pas doubler ce que les modules font.

## Où est la référence

Le `README.md` du checkout de CMakeUtils est la référence complète (tous les mots-clés, variables et dispositions d'installation) et il suit le code. Ce skill n'en garde que l'essentiel et ajoute ce qu'on n'apprend qu'à l'usage. Dès qu'un détail manque, lire la section du README concernée, puis `Utils/*.cmake` (trois fichiers courts) si elle ne suffit pas.

- Dans ce dépôt : `README.md` à la racine.
- Dans un projet qui utilise CMakeUtils : chercher `CMakeUtils` dans ses `CMakeLists.txt` (`include(.../CMakeUtils.cmake)` ou `CMAKE_MODULE_PATH`) pour trouver le checkout. C'est cette version qui fait foi.

Pour modifier les modules eux-mêmes, lire d'abord [references/maintenance.md](references/maintenance.md).

## Un dossier, une target

```
MonProjet/
├── CMakeLists.txt        project(), include(CMakeUtils.cmake), find_package(), add_subdirectory()
├── Core/
│   ├── CMakeLists.txt    cmu_add_static_library(NAME Core)
│   ├── include/          en-têtes publics (*.h)
│   └── src/              sources (*.cpp) et en-têtes privés
└── App/
    ├── CMakeLists.txt    cmu_add_executable(NAME App LINK_LIBRARIES PRIVATE Core)
    └── src/main.cpp
```

`cmu_add_target` prend récursivement tout `src/` et tout `include/` du dossier de son `CMakeLists.txt`. Deux targets déclarées dans le même dossier compileraient donc les mêmes fichiers : chaque target a son dossier et son `CMakeLists.txt`.

```cmake
cmake_minimum_required(VERSION 3.19)
project(MonProjet VERSION 1.0.0 LANGUAGES CXX)

include(chemin/vers/CMakeUtils/CMakeUtils.cmake)

find_package(Qt6 REQUIRED COMPONENTS Core)

# Exécutables et DLL côte à côte, pour que les DLL du projet soient trouvées au lancement.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_subdirectory(Core)
add_subdirectory(App)
```

L'ordre compte :

- `include` après `project()` : CMakeUtils lit les capacités du compilateur, connues seulement après. Sinon : `CMakeUtils must be included after project()`.
- `find_package` après `include` : l'inclusion ajoute `QTDIR` au chemin de recherche et mémorise les `find_package` suivants pour les rejouer dans les fichiers `Config.cmake` générés.
- Bibliothèques avant exécutables : le déploiement de Qt examine les dépendances d'un exécutable à la fin de son `CMakeLists.txt` et ne voit que les targets déjà déclarées.
- `VERSION` dans `project()` : c'est la version des targets et du paquet. Sans elle tout est en `0.0.0`, que `find_package(MonProjet 1.0)` refuse.
- CMake 3.19 : nécessaire à l'installation automatique, au déploiement de Qt et aux en-têtes des targets `INTERFACE`. `cmu_add_target` seul fonctionne dès 3.13.

## Aide-mémoire

| Macro                                | Target                                                    |
| ------------------------------------ | --------------------------------------------------------- |
| `cmu_add_executable`                 | exécutable                                                |
| `cmu_add_static_library`             | bibliothèque statique                                     |
| `cmu_add_shared_library`             | bibliothèque partagée                                     |
| `cmu_add_interface_library`          | bibliothèque d'en-têtes seuls                             |
| `cmu_add_object_library`             | bibliothèque objet (ni installée ni exportée)             |
| `cmu_add_target(... TYPE MODULE)`    | module chargé à l'exécution (pas de raccourci)            |

```cmake
cmu_add_shared_library(
    NAME Core                                   # obligatoire ; donne aussi CORE_EXPORT et CoreInfo
    NAMESPACE MonProjet                         # alias MonProjet::Core
    VERSION 1.2.0                               # défaut : PROJECT_VERSION, sinon 0.0.0
    SOURCES generated/table.cpp                 # en plus des fichiers trouvés ; relatif à src/
    COMPILE_DEFINITIONS PUBLIC CORE_API=2 PRIVATE CORE_TRACE
    LINK_LIBRARIES PUBLIC Qt6::Core PRIVATE Utils
)
```

`INCLUDE_DIRECTORIES`, `COMPILE_DEFINITIONS`, `COMPILE_OPTIONS`, `COMPILE_FEATURES`, `LINK_LIBRARIES` et `LINK_OPTIONS` sont passés tels quels à la commande `target_*` de même nom : la portée s'écrit comme pour elle et plusieurs portées peuvent se suivre. `SHARED_EXTENSION plugin` renomme une bibliothèque partagée en `Core.plugin`.

Les variables se définissent avant `include(CMakeUtils.cmake)` ou avec `-D`. Les quatre premières sont relues à chaque appel `cmu_add_*` : un `set()` juste avant l'appel change la disposition de ce dossier seulement.

| Variable                                                   | Défaut            | Rôle                                                  |
| ---------------------------------------------------------- | ----------------- | ----------------------------------------------------- |
| `cmu_sources_dir`                                          | `src`             | sources et en-têtes privés                            |
| `cmu_public_headers_dir`                                   | `include`         | en-têtes publics                                      |
| `cmu_sources_extension`                                    | `cpp`             | extensions prises dans `cmu_sources_dir` (liste)      |
| `cmu_headers_extension`                                    | `h`               | extensions prises dans `cmu_public_headers_dir` (liste) |
| `cmu_organization`, `cmu_organization_domain`, `cmu_copyright` | ceux de l'auteur  | écrits dans les fichiers d'informations ; à redéfinir pour un autre éditeur |
| `cmu_package`                                              | `ON`              | installation et copie automatiques                    |
| `cmu_install_mode`                                         | `TARGET`          | `TARGET` : un dossier par target ; `PACKAGE` : un seul préfixe |
| `cmu_package_dir`                                          | `<build>/package` | où le résultat est copié après chaque compilation     |
| `cmu_windeployqt`                                          | `ON`              | déploiement de Qt à côté des exécutables (Windows)    |

## Déjà fait : ne pas le refaire

Écrire ces choses à la main crée des doublons, voire des conflits avec ce que les modules génèrent.

| Besoin                              | Ce que fait CMakeUtils                                                              | À ne pas écrire                                              |
| ----------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Lister les fichiers                 | Recherche récursive avec `CONFIGURE_DEPENDS` : un nouveau fichier est pris à la compilation suivante | liste de sources, `file(GLOB)`                               |
| Dossiers d'inclusion                | `include/` en `PUBLIC`, `src/` en `PRIVATE`                                         | `target_include_directories` pour ces deux dossiers          |
| Export des symboles                 | `<NAME>_export.h`, produit par `generate_export_header`, définit `<NAME>_EXPORT`, `<NAME>_NO_EXPORT` et `<NAME>_DEPRECATED` | second `generate_export_header`, macro d'export maison, `WINDOWS_EXPORT_ALL_SYMBOLS` |
| Version et identité dans le code    | `<NAME>_info.h` : `<NAME>Info::name`, `version`, `product`, `organization`, `about`... | `configure_file` d'un en-tête de version                     |
| Propriétés du fichier sous Windows  | ressource `VERSIONINFO` générée pour les exécutables et les DLL                     | bloc `VERSIONINFO` dans un `.rc`                             |
| Standard C++                        | le plus récent du compilateur, sans extensions                                      | `CMAKE_CXX_STANDARD`, sauf pour figer une version            |
| Installation et `find_package`      | règles d'installation, export et fichiers `Config.cmake` pour chaque target         | `install(...)`, `export(...)`, `configure_package_config_file` |
| Trouver et déployer Qt              | `QTDIR` ajouté au chemin de recherche, `windeployqt` après compilation et installation | chemin de Qt en dur, commande de déploiement                 |

## Pièges

Tous observés en pratique ; l'erreur citée est celle que CMake affiche.

1. **Portée oubliée.** `COMPILE_DEFINITIONS FOO=1` donne `target_compile_definitions called with invalid arguments`, signalé dans `target.cmake` et non dans le fichier fautif. Écrire `COMPILE_DEFINITIONS PRIVATE FOO=1`.

2. **Fichier ignoré sans message.** Seuls `src/**/*.cpp` et `include/**/*.h` sont pris. Un `.cc`, un `.hpp` ou un `.qrc` n'entre pas dans la target, et un en-tête public `.hpp` n'est pas installé non plus. Étendre les listes avant l'inclusion (`set(cmu_headers_extension "h;hpp")`) ou nommer le fichier dans `SOURCES`.

3. **`SOURCES` part de `src/`.** `SOURCES util/x.cpp` désigne `src/util/x.cpp`. Pour un fichier ailleurs : `../autre/x.cpp` ou un chemin absolu (`${CMAKE_CURRENT_SOURCE_DIR}/autre/x.cpp`).

4. **Une bibliothèque liée à une target du projet créée hors CMakeUtils.** Avec `add_library` classique ou une dépendance compilée dans l'arbre (`FetchContent`, `add_subdirectory` d'un tiers), la génération échoue : `install(EXPORT "CoreTargets" ...) includes target "Core" which requires target "x" that is not in any export set`. Même en `PRIVATE` pour une bibliothèque statique, car l'export doit décrire ce qu'il faut lier. Créer la dépendance avec `cmu_add_*`, l'obtenir par `find_package`, ou couper l'installation automatique (`-Dcmu_package=OFF`). Les exécutables ne sont pas concernés.

5. **Dossier d'inclusion `PUBLIC` supplémentaire.** Un chemin de l'arbre de sources ne peut pas être exporté : l'envelopper dans `$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/dossier>`. Le plus simple reste de mettre les en-têtes publics dans `include/`.

6. **Lier les targets du projet par leur nom, pas par leur alias.** `LINK_LIBRARIES PUBLIC Core`, non `MonProjet::Core`. En mode `TARGET`, le `Config.cmake` d'un composant ne reconnaît ses voisins que par leur nom : avec l'alias, `find_package(MonProjet COMPONENTS App)` échoue chez l'utilisateur du paquet (`imported targets are referenced, but are missing`). L'alias `NAMESPACE` sert aux projets qui englobent celui-ci.

7. **`\` dans un argument.** Les `cmu_add_*` sont des macros et réévaluent leurs arguments : `Invalid character escape`. Toujours `/` dans les chemins.

8. **`<NAME>_info.h` est privé.** Il n'est visible que des sources de sa target, n'est pas installé et demande C++17. Pour exposer la version d'une bibliothèque, écrire une fonction publique qui renvoie `CoreInfo::version`.

9. **Tout ce qui est créé par `cmu_add_*` est installé**, exécutables de test compris. Créer ceux-ci avec `add_executable` classique, ou choisir la liste avec `cmu_install_targets(TARGETS ...)` à la racine après les `add_subdirectory`. Cet appel remplace l'installation automatique, copie dans `<build>/package` comprise : il ne reste que `cmake --install`.

10. **Qt : `AUTOMOC`, `AUTOUIC` et `AUTORCC` ne sont pas activés.** Ajouter `set(CMAKE_AUTOMOC ON)` (et les autres au besoin) à la racine, avant les `add_subdirectory`. Un `.qrc` se nomme dans `SOURCES`.

11. **Le standard C++ suit le compilateur** (C++23 avec MSVC récent). Si du code ne compile plus après une mise à jour de l'outil, figer : `set(CMAKE_CXX_STANDARD 20)` avant l'inclusion.

12. **Les réglages `cmu_*` sont en cache.** Changer `cmu_install_mode` demande un `-D` explicite ou un dossier de build neuf ; il en va de même du préfixe d'installation par défaut (`<build>/../install`), fixé à la première configuration.

## Recettes

**Bibliothèque partagée.** L'en-tête public inclut l'en-tête généré et marque ce qui est exporté :

```cmake
# Core/CMakeLists.txt
cmu_add_shared_library(NAME Core)
```

```cpp
// Core/include/Core.h
#pragma once
#include "Core_export.h"

CORE_EXPORT int coreValue();
class CORE_EXPORT Engine { /* ... */ };
```

Le préfixe est le nom de la target en majuscules, réduit à un identifiant C : `My-Lib` donne `MY_LIB_EXPORT` dans `My-Lib_export.h`, et le namespace d'informations `My_LibInfo`. Pour une bibliothèque statique, `<NAME>_EXPORT` est vide : garder la macro permet de changer de type sans toucher au code.

**En-têtes seuls.** Un dossier `include/` et `cmu_add_interface_library(NAME Maths)`. Rien d'autre.

**Application Qt.**

```cmake
# CMakeLists.txt, après include(CMakeUtils.cmake)
find_package(Qt6 REQUIRED COMPONENTS Core Widgets)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
```

```cmake
# App/CMakeLists.txt
cmu_add_executable(
    NAME App
    SOURCES resources.qrc
    LINK_LIBRARIES PRIVATE Core Qt6::Widgets
)
```

`AppInfo` (dans `App_info.h`) fournit de quoi renseigner `QCoreApplication` : `name`, `version`, `organization`, `organizationDomain`. Ce sont des `std::string_view`, à convertir avec `QString::fromUtf8(v.data(), v.size())`.

**Disposition différente pour un dossier.** Par exemple sources et en-têtes à plat :

```cmake
set(cmu_sources_dir ".")
set(cmu_public_headers_dir ".")
cmu_add_static_library(NAME Legacy)
```

**Utiliser le résultat depuis un autre projet.** Après compilation, `<build>/package` contient le paquet ; `cmake --install` produit le même dans `<build>/../install`.

```cmake
# Mode TARGET (défaut) : chaque target est un composant, dans <préfixe>/<target>/<config>/
find_package(MonProjet 1.0 REQUIRED COMPONENTS Core)
target_link_libraries(app PRIVATE MonProjet::Core)
```

```cmake
# Mode PACKAGE (-Dcmu_install_mode=PACKAGE) : un seul préfixe bin/ lib/ include/
find_package(MonProjet 1.0 REQUIRED)
target_link_libraries(app PRIVATE MonProjet::Core)
```

Dans les deux cas, pointer `CMAKE_PREFIX_PATH` sur le préfixe. Pour choisir le nom, les targets ou les dépendances du paquet, voir `cmu_add_package` dans le README.

## Vérifier

Une erreur d'export ou de déploiement n'apparaît qu'à la génération ou à la compilation : configurer ne suffit pas.

```bash
cmake -S . -B build
```

```bash
cmake --build build --config Debug
```

Puis regarder le résultat plutôt que de le supposer :

- la configuration se termine sans avertissement `CMakeUtils:` ni `CMake Warning` ;
- `build/package/` contient chaque target attendue, avec ses en-têtes publics et, pour un exécutable, les DLL dont il dépend ;
- l'exécutable se lance depuis `build/package/<target>/<config>/bin/` (mode `TARGET`), ce qui prouve que le déploiement est complet ;
- pour un paquet destiné à d'autres, un petit projet qui fait `find_package` sur `build/package` est le seul vrai test.
