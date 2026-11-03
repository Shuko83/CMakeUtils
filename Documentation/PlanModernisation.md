# StreamWork : plan de modernisation

## 1. Objectifs

- Compiler en **C++20**.
- Supprimer les classes inutiles.
- Passer à un format **JSON**, en gardant la lecture des anciens fichiers XML (stream et conf).
- Supprimer **LibIndeSig** (« libsig ») et la plupart des dépendances **Qst**.
- Préparer une migration facile vers **Qt 6** (non planifiée à ce jour).
- Ajouter ensuite de nouvelles fonctionnalités.

Décisions prises :

| Sujet | Décision |
|---|---|
| Qt 5.9.6 et MSVC 2015 | Abandonnés. Cibles : MSVC 2022 + Qt 5.15, GCC 11.3 + Qt 5.15. |
| Version | Le nouveau framework est livré en **version majeure**. |
| Plugins `.swdl` tiers | Recompilation nécessaire. Phase de dépréciation prévue. |
| Signaux | Qt natif pour les classes `QObject`. Pour les autres : observateurs ou `SwSignal` (hors Qt). |
| Fichiers XML | Toujours ouverts. Conversion vers JSON proposée à l'utilisateur. |

## 2. État actuel (audit)

- Aucun standard C++ n'est fixé dans CMake. Il y a 15 modules et environ 600 fichiers. Il n'y a aucun test unitaire.
- **LibIndeSig** : `SwCore/include/Tools/Signal/LibIndeSig.h`.
  - Il se compose de `iSignal0..7` avec `iconnect` et `idisconnect`.
  - Il est inclus dans environ 35 fichiers, avec environ 190 appels.
  - `SwRef` en dépend (`getOnDestroySignal`).
- **Qst** : `QsException` est lié partout, `QsCore` et `QsGui` dans 4 modules, `QsLog` dans 2 (`main.cpp`, `SwPropertyPersistentToolbox.cpp`).
  - Beaucoup de liens CMake sont probablement inutiles.
  - Des équivalents locaux existent : `SwException.h` et `Tools/Log/*`.
- **Persistance** : tout est en XML (`QDomDocument`, `QXmlStreamWriter/Reader`).

| Fichier | Classes principales |
|---|---|
| Stream (`.xml`) | `SwSaver_Class`, `SwLoader_Class`, `StreamControler` |
| Graphique | `GraphicsLoaderV1` |
| Conf (`.conf`) | `SwServiceSaveConfiguration`, `_SwManagedConfigurationsList` |
| Enregistrement | `Record.xml` (`_RecordManager`, `_TimeLine`) |
| Disposition GUI | `dockParameters.xml` |
| Réglages | `QSettings` (`.ini`) |

- **Dette** :
  - 171 `NULL` ;
  - 83 `new`/`delete` ;
  - `qSort`, `QRegExp`, `foreach` ;
  - 6 singletons ;
  - `SwRefPtr` (équivalent maison de `shared_ptr`) ;
  - macros `SIGNAL()`/`SLOT()` (26 occurrences) ;
  - `#pragma` MSVC.

## 3. Règles de commit

- Chaque commit compile sur toutes les plateformes cibles et passe les tests.
- On ne mélange jamais changement mécanique (renommage, `nullptr`) et changement fonctionnel.
- Les commits mécaniques sont faits par module. Le message indique l'outil utilisé (clang-tidy ou script).
- Une classe supprimée, ou un groupe cohérent, par commit.
- Les fichiers de référence de la phase 0 prouvent que les anciens fichiers se chargent toujours.

## 4. Phases

### Phase 0 : filet de sécurité

1. `chore` : `.editorconfig`, `.clang-format`, `.gitattributes`. Le reformatage est isolé et ajouté à `.git-blame-ignore-revs`.
2. `test` : infrastructure `ctest` (Catch2 ou GoogleTest), dossier `tests/`, étape Jenkins.
3. `test` : fichiers de référence. On capture des streams, `.conf` et `Record.xml` produits par la version actuelle. Les tests font charger, sauver, recharger et comparer.
4. `ci` : retrait de MSVC 2015 et Qt 5.9.6.
5. `ci` : `QT_DISABLE_DEPRECATED_BEFORE=0x060000`, en avertissement seulement. On obtient la liste des API qui disparaissent en Qt 6.

### Phase 1 : C++20 et modernisation mécanique

1. `build` : `CMAKE_CXX_STANDARD 20` (`REQUIRED`, `EXTENSIONS OFF`) défini une fois à la racine. Ce commit ne contient que les corrections de compilation : `throw()` vers `noexcept`, `[=]` capturant `this`, ambiguïtés de comparaison, `std::bind1st`.
2. Un commit par idiome et par module :
   - `NULL` vers `nullptr` ;
   - ajout de `override` ;
   - `typedef` vers `using` ;
   - `foreach` vers range-for (avec `std::as_const` si nécessaire) ;
   - `qSort` vers `std::sort`.
3. `refactor` : `QRegExp` vers `QRegularExpression`. Commit séparé, car la sémantique change.
4. `build` : activation de `/W4` et `-Wall -Wextra`, suppression des `#pragma warning` et correction des causes.

### Phase 1 bis : préparation à Qt 6

- `build` : cibles Qt sans version (`find_package(QT NAMES Qt5 Qt6 ...)`, `Qt::Core`, `Qt::Widgets`, `Qt::Xml`).
- `refactor` : `SIGNAL()`/`SLOT()` remplacés par `connect()` à pointeur de membre. Cela concerne `_SwConfigurationManagerGui.cpp`, `_SwSwitchExecution_Service.cpp`, `_SwSwitchExecutionSetup.cpp` et deux autres fichiers.
- `refactor` : `QTextCodec`, `QStringRef` et `QString::SkipEmptyParts` (vers `Qt::SkipEmptyParts`).
- `refactor` : `QVariant::type()` et `QMetaType::type()` vers `typeId()`. Cela touche `SwPropertyPersistentToolbox` et les types utilisateur. À faire avant le JSON, qui est typé.
- `refactor` : `QVector` et `QList`, `QMutex::Recursive`, `QDesktopWidget`, autres signalements du compilateur.
- Notes :
  - `Qt5::Designer` (SwGui) et OpenGL (StreamWorkEditor) changent de module en Qt 6.
  - Qst est précompilé pour Qt 5. La phase 6 doit donc précéder tout passage à Qt 6.

### Phase 2 : suppression du code inutile

Méthode : dresser la liste des candidats par références (`grep`), fichiers `.map` du linker et clang-tidy. La liste est consignée dans un commit `docs`.

Candidats probables :
- `_SwSimpleExecutable` et `_SwSimpleDataExecutable` (fixtures de test, à déplacer dans `tests/`).
- `_SwQAbstractItemViewSlots_Catcher`.
- Les doublons `SwPropertiesModelImpl` (SwCore) et `_SwPropertiesModelImpl` (SwGui).
- Le triple emploi des loggers : `SwLogger_Class`, `SwAlerter_Class`, `QsLog`.
- Les modules trop petits : SwFoundation, SwLauncher, SwDataBase (fusion à étudier).
- Les 6 singletons : un commit par singleton.

Attention : un composant supprimé et référencé par une ancienne stream casse son chargement. Pour chaque composant, il faut choisir entre suppression franche, alias de chargement, ou dépréciation d'abord.

### Phase 3 : remplacement de LibIndeSig

Choix d'architecture :
- **Classes `QObject` ou GUI** : signaux Qt natifs avec `connect` à pointeur de membre.
- **Classes métier non-`QObject`** (`SwComponent_Class`, propriétés, `SwRef`, services, exports de configuration) :
  - `SwSignal<Args...>` indépendant de Qt, avec `connect(obj, &T::method)` retournant un `SwConnection` RAII ;
  - interfaces observateurs (`registerObserver`, `unregisterObserver`) quand plusieurs signaux forment un contrat cohérent. Exemple : `OnAddChild`, `OnRemoveChild` et `OnChangeComponentName` regroupés en `ISwComponentObserver`.
- Les composants ne deviennent pas des `QObject`. Cela imposerait Qt aux plugins et alourdirait les objets.

Commits :
1. `feat(core)` : `SwSignal<Args...>` variadique C++20, avec tests (ordre d'appel, déconnexion pendant l'émission, durée de vie).
2. `refactor` : `iSignalN` devient un alias de `SwSignal`. Les membres publics (`OnParentChange`, `OnAddChild`, `GetOnChangeSignal()`) gardent leur nom. `iconnect` et `idisconnect` deviennent des shims `[[deprecated]]`.
3. Migration interne par module vers `connect()` avec `SwConnection` stocké en membre. Les `idisconnect` des destructeurs disparaissent. Ordre : SwCore, SwExecution, SwModel, SwConfiguration, SwEditor, SwGui, StreamWorkEditor.
4. `feat` : interfaces observateurs pour les contrats cohérents.
5. `chore` : `LibIndeSig.h` vidé et marqué deprecated. Sa suppression a lieu à la fin de la période de dépréciation.

### Phase 4 (optionnelle) : `SwRef` et gestion mémoire

`SwRef` et `SwRefPtr` se comportent comme un observateur de destruction, plus proche d'un `weak_ptr` que d'un `shared_ptr`. Pas de remplacement direct.
- Analyse d'ownership, puis `SwWeakRef<T>` construit sur `SwSignal`.
- Ensuite, `new`/`delete` vers `std::unique_ptr` et `make_unique`, module par module, en commençant par `Component.cpp`.

### Phase 5 : format JSON et conversion XML vers JSON

Voir la section 5 ci-dessous.

### Phase 6 : réduction de Qst

1. `build` : retirer un à un `QstModules::QsException`, `QsCore` et `QsGui` de chaque `CMakeLists.txt`, et corriger ce qui casse.
2. `refactor` : exceptions sur `SwException`, dérivée de `std::exception`.
3. `refactor` : `QsLog` remplacé par `ISwLogger`, branché sur `QLoggingCategory`. Le remplaçant de `QS_CATEGORY` est à définir.
4. `refactor` : un commit par utilitaire `QsCore` ou `QsGui` encore utilisé (équivalent Qt, STL ou code interne).
5. `build` : suppression du `fetch` de `QstBase` et `QstModules` dans le `CMakeLists.txt` racine, si plus rien n'est utilisé.

### Phase 7 : nouvelles fonctionnalités

- Schéma JSON validé.
- Mode headless et CLI.
- Tests d'intégration sur les exécuteurs.
- Modules étendus (voir `TODOList.txt`).

## 5. JSON et convertisseur XML vers JSON

### 5.1 Principe

- Le nouveau framework (version majeure) **écrit en JSON** par défaut.
- Il **lit toujours le XML** pendant toute la durée de vie de cette version majeure.
- À l'ouverture d'un fichier XML (stream ou conf), l'utilisateur se voit proposer la conversion. **Rien n'est converti sans accord.**
- Le JSON utilise `QJsonDocument` (`Qt::Core`), donc aucune nouvelle dépendance.

### 5.2 Format JSON

Chaque fichier porte un en-tête de version :

```json
{
  "format": "streamwork.stream",
  "version": 1,
  "...": "..."
}
```

Valeurs de `format` : `streamwork.stream`, `streamwork.conf`, `streamwork.record`, `streamwork.layout`.
Les valeurs de propriétés sont typées (nombres, booléens, listes, énumérations). En XML, ce sont des chaînes. Le mapping est à spécifier dans un commit `docs`.

### 5.3 Architecture

```
Fichier .xml  --> XmlCodec  --\
                               >--> SwArchive (arbre neutre) --> composants (Load)
Fichier .json --> JsonCodec --/
composants (Save) --> SwArchive --> JsonCodec --> .json
```

- `SwArchive` est un arbre neutre (nœuds, attributs, valeurs `QVariant`). Les composants ne dépendent plus de `QDomDocument` ni de `QXmlStreamWriter`.
- `XmlCodec` reproduit exactement le comportement actuel. Il est validé par les fichiers de référence de la phase 0.
- `JsonCodec` est nouveau.
- Les interfaces `ISwPersistent` et `ISwPersistentConfigurable` reçoivent `Save(SwArchiveWriter&)` et `Load(SwArchiveReader&)`. Les anciennes signatures (`Save(QXmlStreamWriter&)`) restent en `[[deprecated]]` avec un pont par défaut.

### 5.4 Convertisseur XML vers JSON

Le convertisseur est une fonction de bibliothèque : `SwConverter::convert(inPath, outPath, kind)`.
- Principe : `XmlCodec` lit vers `SwArchive`, puis `JsonCodec` écrit.
- Il est utilisé à deux endroits : la GUI et la ligne de commande.

**Comportement dans l'application (stream et conf identiques)**

1. L'utilisateur ouvre un fichier `.xml`.
2. Le framework le charge via `XmlCodec`.
3. Une boîte de dialogue propose : « Ce fichier utilise l'ancien format XML. Enregistrer au nouveau format JSON ? ».
4. Si oui, un nouveau fichier `.json` est écrit à côté de l'original. L'original reste intact (renommé `.xml.bak` si l'utilisateur choisit de remplacer).
5. Si non, le fichier reste en XML. La question se repose à la prochaine ouverture, sauf case « ne plus demander » (réglage dans `GlobalConf`).
6. Un enregistrement (Ctrl+S) d'un fichier ouvert en XML reste en XML tant que l'utilisateur n'a pas accepté la conversion.

**Ligne de commande**

```
streamwork --convert entree.xml sortie.json
streamwork --convert-dir ./streams --recursive
```

Utile pour migrer des lots de fichiers et dans la CI.

### 5.5 Garanties et tests

- Aller-retour XML vers JSON vers XML : mêmes données que l'original (tests sur les fichiers de référence).
- Tests de chargement : le JSON converti produit un composant identique à celui chargé depuis le XML.
- Un fichier invalide ou d'une version future est refusé avec un message clair. Il n'est pas converti.
- Détection du format à l'ouverture : extension, ou premier caractère non blanc (`<` ou `{`).

### 5.6 Cas particuliers

- **Graphique** : `GraphicsLoaderV1` reste en lecture. On ajoute `GraphicsLoaderV2` en JSON.
- **Fichiers `.conf`** : mêmes règles de conversion que le stream.
- **`Record.xml` et `dockParameters.xml`** : un commit par fichier, avec lecture des deux formats.
- **`.ini` (`QSettings`)** : conservé ou migré à part.

### 5.7 Commits

1. `docs` : spécification JSON et mapping des types.
2. `feat(core)` : `SwArchive`, `XmlCodec`, `JsonCodec` (aucun changement de comportement).
3. `feat` : détection de format au chargement.
4. Extension des interfaces, avec une série de commits par classe ou groupe (`SwProperties_Class`, `SwController_Class`, `SwPins_Manager_Class`, `SwInterfaces_Consumer_Class`, puis éditeur, exécution, modèle).
5. `feat` : sérialisation typée dans `SwPropertyPersistentToolbox`.
6. `feat` : `GraphicsLoaderV2`.
7. `feat` : `.conf`, `Record`, `dockParameters` en JSON.
8. `feat` : `SwConverter` et ligne de commande `--convert`.
9. `feat` : dialogue de conversion dans l'application (stream, puis conf).
10. `test` : aller-retour XML vers JSON vers XML.
11. `feat` : le JSON devient le format d'écriture par défaut.

## 6. Plugins `.swdl` et dépréciation

- Les plugins tiers doivent être **recompilés** : C++20 et la nouvelle API changent l'ABI.
- Chaque `.swdl` exporte `SW_PLUGIN_API_VERSION`. `_SwPluginsBank_Class` la vérifie au chargement. Un plugin trop ancien est refusé avec un message clair, pas de crash.
- Calendrier :

| Version | Contenu |
|---|---|
| Majeure N | Nouvelle API. Ancienne API marquée `[[deprecated("...")]]` (`iconnect`, `idisconnect`, `LibIndeSig::`, `Save(QXmlStreamWriter&)`, `Load(QDomDocument&)`). Lecture XML conservée. |
| N.x | Avertissements conservés. Guide de migration publié. |
| Majeure N+1 | Suppression des API dépréciées et de l'écriture XML. La lecture XML peut rester via le convertisseur. |

- Livrables pour les équipes tierces :
  - guide de migration court (tableau « ancien appel / nouvel appel ») dans `Documentation/` ;
  - script de conversion mécanique, par exemple `x.iconnect(*this, &T::f)` vers `x.connect(this, &T::f)`.

## 7. Ordre global

1. Phase 0 : tests, CI, avertissements Qt 6.
2. Phase 1 : C++20 et modernisation mécanique.
3. Phase 1 bis : préparation Qt 6.
4. Phase 2 : suppression du code inutile.
5. Phase 3 : signaux et API de version des plugins (en parallèle de la phase 6).
6. Phase 6 : Qst.
7. Phase 5 : JSON et convertisseur (bénéficie de la phase 1 bis pour le typage `QVariant`).
8. Phase 4 : `SwRef` (optionnelle).
9. Phase 7 : nouvelles fonctionnalités.
10. Publication de la version majeure.
