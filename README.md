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

`CMakeUtils.cmake` définit sept variables de cache (type `STRING`), sans toucher à une valeur déjà définie avant l'inclusion (variable normale ou `-D` en ligne de commande) :

| Variable                 | Défaut    | Rôle                                                    |
| ------------------------ | --------- | ------------------------------------------------------- |
| `cmu_public_headers_dir` | `include` | Dossier des en-têtes publics                            |
| `cmu_sources_dir`        | `src`     | Dossier des sources et en-têtes privés                  |
| `cmu_sources_extension`  | `cpp`     | Extension(s) des sources (liste, ex. `cpp;cc`)          |
| `cmu_headers_extension`  | `h`       | Extension(s) des en-têtes (liste, ex. `h;hpp`)          |
| `cmu_organization`       | `Shuko83` | Organisation écrite dans l'en-tête d'informations de chaque target |
| `cmu_organization_domain` | `https://github.com/Shuko83` | Domaine de l'organisation (ex. `example.com`), écrit dans le même en-tête |
| `cmu_copyright`          | `Copyright (C) <année> <cmu_organization>` | Copyright des targets ; l'année est celle de la première configuration |

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
    [NAMESPACE <namespace>]
    [VERSION <version>]
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
| `NAMESPACE`           | Crée l'alias `<namespace>::<NAME>` de la target, avec ou sans `::` final (`namespace` ou `namespace::`) |
| `VERSION`             | Version de la target écrite dans l'en-tête d'informations (défaut : `PROJECT_VERSION`, sinon `0.0.0`) |
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

Pour chaque target qui n'est ni `INTERFACE` ni `EXECUTABLE`, l'en-tête public `<NAME>_export.h` est généré avec `generate_export_header()` de CMake dans `<build>/<dossier>/<NAME>_autogen/cmu/public`. Ce dossier est ajouté en `PUBLIC` (arbre de build uniquement) et l'en-tête est installé avec les en-têtes publics, à plat dans `include` : `#include "<NAME>_export.h"`. Il définit `<NAME>_EXPORT` (`<NAME>` en majuscules, réduit à un identifiant C : `MySharedLib` → `MYSHAREDLIB_EXPORT`), à placer devant les symboles exportés, ainsi que `<NAME>_NO_EXPORT` et `<NAME>_DEPRECATED`. Pour une bibliothèque `SHARED` ou `MODULE`, `<NAME>_EXPORTS` est définie par CMake pendant la compilation de la target (`dllexport`), sinon `dllimport` ; pour les autres types, `<NAME>_STATIC_DEFINE` est définie en `PUBLIC` et la macro est vide.

Pour chaque target non `INTERFACE`, les fichiers `<NAME>_info.h` et `<NAME>_info.cpp` sont générés depuis [Template/target_info.h.in](Template/target_info.h.in) et [Template/target_info.cpp.in](Template/target_info.cpp.in) dans `<build>/<dossier>/<NAME>_autogen/cmu/include`. Ce dossier est ajouté en `PRIVATE` et le `.cpp` est compilé avec la target. Ils définissent, en C++ récent, des `std::string_view` dans le namespace `<NAME>Info` (`Core` → `CoreInfo`) :

| Symbole        | Contenu                                                                  |
| -------------- | ------------------------------------------------------------------------ |
| `name`         | Nom de la target                                                         |
| `version`      | Version (`VERSION`)                                                      |
| `product`      | Nom du projet CMake (`PROJECT_NAME`)                                     |
| `organization` | `cmu_organization`                                                       |
| `organizationDomain` | `cmu_organization_domain`                                          |
| `copyright`    | `cmu_copyright`                                                          |
| `qtVersion`    | Version de Qt trouvée par `find_package` (`none` sinon)                  |
| `compiler`     | Compilateur et sa version (ex. `MSVC 19.51.36260.0`)                     |
| `buildDate`    | Date et heure de compilation du `.cpp` généré (`__DATE__ " " __TIME__`)  |
| `about`        | Trois lignes : `Qt: ...`, `Compiler: ...`, `Build date: ...`             |

Dans le projet Visual Studio, les fichiers générés par CMakeUtils sont regroupés dans le dossier `autogen\cmu` (`source_group`), et ceux de Qt dans les sous-dossiers `autogen\moc` (`mocs_compilation*.cpp`), `autogen\rcc` (`qrc_*.cpp`) et `autogen\uic` (`ui_*.h`).

Sous Windows, les exécutables et les bibliothèques `SHARED` ou `MODULE` reçoivent aussi une ressource de version `<NAME>_info.rc` (depuis [Template/target_info.rc.in](Template/target_info.rc.in)), visible dans l'onglet Détails des propriétés du fichier : société (`organization`), description et nom interne (`name`), nom d'origine du fichier, produit (`product`), copyright (`copyright`) et version (`version`). La version numérique est lue depuis `version` en `major.minor.patch.0` (0 si une partie manque ou n'est pas numérique).

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
# MySharedLib/CMakeLists.txt : bibliothèque partagée (MySharedLib_export.h, généré, définit MYSHAREDLIB_EXPORT)
cmu_add_shared_library(
    NAME MySharedLib
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
- `cmu_public_headers_dir` n'est visible que depuis l'arbre de sources (`$<BUILD_INTERFACE:...>`) pour que la target soit exportable ; `cmu_add_package` fournit le chemin d'installation.

### package.cmake

#### Mode d'installation

Sans rien changer au `CMakeLists.txt`, toutes les targets créées avec `cmu_add_target` (sauf `OBJECT`) sont installées par `cmake --install`, et copiées dans `<build>/package` (variable `cmu_package_dir`) une fois la compilation finie par la target `cmu_package`, incluse dans `ALL`. La variable `cmu_install_mode` choisit la façon d'installer :

| `cmu_install_mode`  | Disposition                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------- |
| `TARGET` (défaut)   | Chaque target dans son dossier : `<prefix>/<target>/<config>/{bin,lib,include}`                   |
| `PACKAGE`           | Tout dans un seul préfixe, avec les fichiers `Config.cmake` pour `find_package` (voir plus bas)   |

| Variable           | Défaut            | Rôle                                                  |
| ------------------ | ----------------- | ----------------------------------------------------- |
| `cmu_package`      | `ON`              | `OFF` désactive l'installation automatique            |
| `cmu_package_dir`  | `<build>/package` | Dossier où le résultat est copié après la compilation |
| `cmu_install_mode` | `TARGET`          | `TARGET` ou `PACKAGE`                                 |

#### Mode `TARGET`

Avec le préfixe par défaut (`<build>/../install`), `cmake --install --config Debug` donne :

```
install/
├── MyStaticLib/Debug/    include/MyStaticLib.h, include/MyStaticLib_export.h, lib/MyStaticLib.lib
├── MySharedLib/Debug/    include/MySharedLib.h, include/MySharedLib_export.h, lib/MySharedLib.lib, bin/MySharedLib.dll
├── MyApp/Debug/          bin/MyApp.exe, bin/MySharedLib.dll
└── MyQtApp/Debug/        bin/MyQtApp.exe, bin/MySharedLib.dll, bin/Qt6Cored.dll, ...
```

- Une bibliothèque installe ses binaires et ses en-têtes publics (`cmu_public_headers_dir`).
- Un exécutable est prêt à être lancé : les bibliothèques partagées du projet dont il dépend sont copiées dans son `bin/`, et `windeployqt` y déploie Qt s'il en dépend (voir [qt.cmake](#qtcmake)).
- Les configurations coexistent (`Debug`, `Release`) sous chaque target. Un préfixe choisi avec `-DCMAKE_INSTALL_PREFIX=...` ou `cmake --install --prefix ...` garde la même disposition `<prefix>/<target>/<config>`.
- `cmu_install_targets(TARGETS <target>...)` fait la même chose pour une liste choisie et remplace l'installation automatique.

Chaque target est un composant du paquet global (nom du projet) : fichiers `.cmake` pour `find_package`.

```
install/
├── exempleConfig.cmake, exempleConfigVersion.cmake      (paquet global, à la racine)
├── MyStaticLib/cmake/   MyStaticLibConfig.cmake, MyStaticLibTargets.cmake, MyStaticLibTargets-<config>.cmake
└── ...                  un sous-dossier cmake/ identique par target
```

- `<target>Targets.cmake` déclare la target importée `<projet>::<target>` et couvre toutes les configurations installées (`Debug`, `Release`), chacune pointant vers son `<target>/<config>/`.
- `<target>Config.cmake` reprend les `find_package()` dont la target a besoin (par exemple Qt) et charge les composants dont elle dépend (`MyQtApp` charge `MyStaticLib` et `MySharedLib`).
- `exempleConfig.cmake` charge les composants demandés, ou tous s'il n'y en a pas, et renseigne `exemple_<composant>_FOUND` ; un composant `REQUIRED` inconnu fait échouer `find_package`.

```cmake
# Projet tiers, avec CMAKE_PREFIX_PATH=chemin/vers/install
find_package(exemple REQUIRED COMPONENTS MyStaticLib MySharedLib)
target_link_libraries(app PRIVATE exemple::MyStaticLib exemple::MySharedLib)
```

- Sans `COMPONENTS`, tous les composants sont chargés (donc leurs dépendances, comme Qt, doivent être trouvables).
- Les en-têtes publics sont installés dans chaque configuration ; une cible importée utilise ceux de la première configuration installée.
- La version du paquet vient de `project(... VERSION ...)`, `0.0.0` sans version : `find_package(exemple 1.0)` n'accepte pas un paquet en `0.0.0`.

#### Mode `PACKAGE`

`cmake -Dcmu_install_mode=PACKAGE` : une fois la compilation finie, un paquet prêt pour `find_package` dans `<build>/package` :

- `<PROJECT_NAME>Config.cmake`, `<PROJECT_NAME>ConfigVersion.cmake` et `<PROJECT_NAME>Targets.cmake` dans `lib/cmake/<PROJECT_NAME>` ;
- les bibliothèques, les exécutables et les en-têtes publics des targets créées avec `cmu_add_target` (sauf `OBJECT`, non exportable), préfixées par `<PROJECT_NAME>::`.

Une target spéciale `cmu_package`, incluse dans `ALL`, copie le paquet après la dernière target ; `cmake --install` installe les mêmes fichiers.

- La version vient de `project(... VERSION x.y.z)` ; sans version, le paquet est en `0.0.0`.
- Les dépendances sont déduites : un appel à `find_package()` est repris dans `Config.cmake` si une target du paquet est liée à une target `<Paquet>::...` (par exemple `Qt6::Core` pour `find_package(Qt6 REQUIRED COMPONENTS Core)`). Seuls les appels faits après l'inclusion de `CMakeUtils.cmake` sont vus ; si `find_package` est déjà redéfini (vcpkg par exemple), la déduction est désactivée.
- Nécessite CMake 3.19 (`cmake_language(DEFER)`) ; sinon seul `cmu_add_package` est disponible.
- Un appel explicite à `cmu_add_package` remplace le paquet automatique.

#### Dossier d'installation par défaut

Pour le projet racine, `CMAKE_INSTALL_PREFIX` vaut par défaut `<build>/../install`, à côté du dossier de build quel que soit son emplacement. En mode `PACKAGE`, `cmake --install --config <config>` installe dans `<build>/../install/<config>` (par exemple `install/Debug`) ; un préfixe choisi avec `-DCMAKE_INSTALL_PREFIX=...` ou `cmake --install --prefix ...` est alors utilisé tel quel, sans sous-dossier de configuration. En mode `TARGET`, voir plus haut.

#### `cmu_add_package`

Version manuelle, pour choisir le nom, les targets, les dépendances, etc. Génère les fichiers `<NAME>Config.cmake` et `<NAME>ConfigVersion.cmake` lus par `find_package(<NAME>)`, et les installe. Avec `TARGETS`, exporte aussi les targets (`<NAME>Targets.cmake`) et installe les en-têtes publics.

```cmake
cmu_add_package(
    [NAME <nom>]
    [VERSION <x.y.z>]
    [COMPATIBILITY <AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion>]
    [ARCH_INDEPENDENT]
    [NAMESPACE <préfixe>]
    [DESTINATION <dossier>]
    [TARGETS <target>...]
    [HEADERS <dossier>...]
    [DEPENDENCIES <"arguments de find_package">...]
)
```

| Mot-clé            | Rôle                                                                                         | Défaut                                |
| ------------------ | -------------------------------------------------------------------------------------------- | ------------------------------------- |
| `NAME`             | Nom du paquet                                                                                | `PROJECT_NAME`                        |
| `VERSION`          | Version du paquet                                                                            | `PROJECT_VERSION` (obligatoire sinon) |
| `COMPATIBILITY`    | Règle de compatibilité des versions demandées                                                | `SameMajorVersion`                    |
| `ARCH_INDEPENDENT` | Ignore l'architecture (paquet d'en-têtes seuls), CMake 3.14 minimum                          | désactivé                             |
| `NAMESPACE`        | Préfixe des targets exportées                                                                | `<NAME>::`                            |
| `DESTINATION`      | Dossier d'installation des fichiers `.cmake`, relatif au préfixe                             | `lib/cmake/<NAME>`                    |
| `TARGETS`          | Targets installées et exportées                                                              | aucune                                |
| `HEADERS`          | Dossiers d'en-têtes installés dans `include` (filtrés par `cmu_headers_extension`)           | `cmu_public_headers_dir`, s'il existe |
| `DEPENDENCIES`     | Chaque valeur, entre guillemets, devient un `find_dependency(...)` dans `<NAME>Config.cmake` | aucune                                |

Les fichiers sont générés dans `CMAKE_CURRENT_BINARY_DIR`. `HEADERS` sert quand les targets sont dans plusieurs sous-dossiers (le défaut ne vise que le dossier courant).

```cmake
# CMakeLists.txt
project(exemple VERSION 1.2.3 LANGUAGES CXX)
include(chemin/vers/CMakeUtils/CMakeUtils.cmake)

add_subdirectory(MyStaticLib)

cmu_add_package(
    TARGETS MyStaticLib
    HEADERS MyStaticLib/include
)
```

Un projet tiers l'utilise après `cmake --install` :

```cmake
find_package(exemple 1.0 REQUIRED)
target_link_libraries(app PRIVATE exemple::MyStaticLib)
```

Remarques :

- Les dépendances `PRIVATE` d'une bibliothèque statique restent nécessaires à l'édition de liens : les déclarer dans `DEPENDENCIES`.
- Un argument inconnu, une `COMPATIBILITY` invalide ou une version absente arrête la configuration avec un message d'erreur.
- `cmu_add_package` est une fonction : elle ne laisse aucune variable dans la portée de l'appelant.
- Le projet doit être compilé avant `cmake --install`.

### qt.cmake

Ajoute le contenu de la variable d'environnement `QTDIR` (par exemple `C:\Qt\6.11.2\msvc2022_64`) à `CMAKE_PREFIX_PATH`, ce qui permet à `find_package(Qt6 ...)` de trouver Qt sans `-DCMAKE_PREFIX_PATH`.

- Chargé automatiquement par `CMakeUtils.cmake`, ou inclus seul : `include(chemin/vers/CMakeUtils/Utils/qt.cmake)`.
- Le chemin est ajouté à la fin de `CMAKE_PREFIX_PATH` : un chemin déjà présent est prioritaire, et il n'est pas ajouté deux fois.
- Sans effet si `QTDIR` n'est pas définie ou ne désigne pas un dossier existant.
- Doit être inclus avant `find_package(Qt6 ...)`.

#### `windeployqt` automatique

Sous Windows, tout exécutable créé avec `cmu_add_target` (ou `cmu_add_executable`) qui dépend de Qt exécute `windeployqt` après sa compilation : les DLL et plugins Qt sont copiés à côté de l'exécutable. La dépendance est cherchée dans tout le graphe de liens, y compris à travers les bibliothèques (`app` → `core` → `Qt6::Core`).

- `windeployqt` vient de la target `Qt6::windeployqt`, sinon de `windeployqt6` / `windeployqt` trouvé dans `CMAKE_PREFIX_PATH` ou le `PATH` ; s'il est introuvable, un avertissement est affiché.
- À l'installation (`cmake --install` et copie du paquet automatique), `windeployqt` est aussi lancé sur l'exécutable installé : les DLL Qt se retrouvent dans `bin/`, à côté de lui. Cela passe par `cmu_add_package` (automatique ou explicite, avec l'exécutable dans `TARGETS`).
- `-Dcmu_windeployqt=OFF` désactive ce comportement.
- Nécessite CMake 3.19. Seules les bibliothèques déjà déclarées à la fin du `CMakeLists.txt` de l'exécutable sont examinées : ajouter les sous-dossiers des bibliothèques avant celui de l'exécutable.
