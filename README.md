# Clients Orneos

Applications Orneos de bureau (Windows, macOS, Linux) et Android. Ce sont les clients officiels de Nextcloud, **sans fork** : ce dossier ne contient que notre **surcouche** (marque, réglages, icônes) et les scripts qui l'appliquent sur une version officielle précise.

```
versions.env            tags officiels suivis (DESKTOP_TAG, ANDROID_TAG)
brand/                  logo source (mark-1024.svg) ; scripts/make-icons.sh en tire les PNG
desktop/branding.cmake  nom, serveur imposé, flux de mise à jour, GUID Windows
desktop/theme/          icônes et logos qui remplacent ceux de Nextcloud
android/res/            setup.xml (réglages), logos vectoriels, icônes du lanceur
scripts/                apply-*.sh, build-*.sh, check-upstream.sh, make-icons.sh
.github/workflows/      build quotidien (actif quand ce dossier sera son propre dépôt GitHub)
```

## Principe : suivre les versions officielles sans rien casser

1. `scripts/check-upstream.sh` détecte une nouvelle version officielle (`--write` met à jour `versions.env`).
2. On clone le tag officiel, puis `scripts/apply-desktop.sh <dossier>` ou `scripts/apply-android.sh <dossier>` y appliquent la surcouche. Les scripts sont idempotents et **échouent** si un fichier officiel a changé de forme : on ne publie jamais une version à moitié rebrandée.
3. Builds :
   - **bureau** (Linux, Windows, macOS) : la CI GitHub de ce dépôt, chaque jour s'il y a une nouvelle version officielle, ou à la demande. Les binaires arrivent dans une *release* brouillon. Linux peut aussi se construire sur le serveur (`scripts/build-desktop-linux.sh`, image Docker de Nextcloud).
   - **Android** : uniquement sur le serveur d'orneos.eu, car la clé de signature ne le quitte jamais (`private/clients/`). Commande : `tools/client-build.sh android` dans le dépôt orneos.eu. La CI ne fait qu'une compilation de contrôle.
4. Après un essai sur un vrai appareil : `php tools/client-release.php …` (dépôt orneos.eu) publie. Les applications installées se mettent à jour d'elles-mêmes.

Règle : **un patch du code officiel ne se justifie que si aucun réglage de branding ne permet d'obtenir le résultat.** Aujourd'hui, il n'y en a aucun : seules des valeurs sont remplacées (GUID CfApi, nom de l'icône AppImage, numéro de build, `applicationId`). La recette KDE Craft de Nextcloud, qui fabrique l'installeur Windows, est rebrandée de la même façon par `scripts/patch-craft-blueprint.py` (nom affiché, éditeur, exécutable `orneos.exe`).

## Connexion

Aucun choix de serveur :
- bureau : `APPLICATION_SERVER_URL=https://app.orneos.eu` + `APPLICATION_SERVER_URL_ENFORCE` ;
- Android : `webview_login_url` = `https://app.orneos.eu/index.php/login/v2`.

Dans les deux cas, c'est le Login Flow v2 : le navigateur s'ouvre sur la connexion Orneos (login.orneos.eu, double authentification, plusieurs comptes), puis l'app reçoit un mot de passe d'application révocable.

## Mises à jour des utilisateurs

| | Canal | Côté serveur |
|---|---|---|
| Windows | l'updater intégré télécharge l'installeur (`.exe` NSIS) et l'installe en silence (`/S`) | `/updates/desktop` (`ClientUpdateController`) lit `private/clients/desktop.json` |
| macOS | sans Sparkle pour l'instant : un avis « nouvelle version » qui renvoie vers la page Appareils | même flux |
| Linux | notification, lien vers la page Appareils | même flux |
| Android | l'app lit `downloads/android/latest`, propose `orneos-<versionCode>.apk` | fichiers statiques |

Numéro de version : `35.0.0.<AAJJJHH>` (année, jour, heure UTC du build), le même sur le serveur et en CI ; c'est lui que l'updater compare.

## Pas de signature des éditeurs

Choix assumé : ni certificat Windows, ni compte Apple Developer.
- **Windows** : au premier lancement, SmartScreen affiche « Windows a protégé votre ordinateur » → « Informations complémentaires » → « Exécuter quand même ». Les mises à jour suivantes passent sans rien demander.
- **macOS** : l'app n'est signée qu'en « ad hoc ». Au premier lancement, Réglages Système › Confidentialité et sécurité › « Ouvrir quand même ».
- **Android** : signé avec notre propre clé (gratuit, obligatoire), installé hors Play Store (« sources inconnues »).

La page Appareils devra expliquer ces étapes quand les apps y seront proposées.

## Identifiants à ne jamais changer une fois publiés

- Android : `applicationId` `eu.orneos.files`, `account_type` `eu.orneos`, les `authority` de `setup.xml`, la clé de signature `private/clients/android-release.jks` du serveur orneos.eu (sans elle, aucune mise à jour possible : elle doit figurer dans les sauvegardes).
- Windows : `WIN_MSI_UPGRADE_CODE` et les GUID de `branding.cmake` / `apply-desktop.sh`.

## Reste à faire

- **Windows et macOS** : les jobs CI (KDE Craft, mac-crafter) sont à valider au premier passage.
- **macOS** : mises à jour automatiques avec Sparkle (clé EdDSA gratuite, indépendante d'Apple).
- **Talk Android** (`nextcloud/talk-android`) : même principe, même `account_type`. Notifications push à prévoir (proxy et Firebase à nous, ou UnifiedPush).
- **Textes** : quelques traductions officielles disent encore « Nextcloud » en dur ; à reprendre par surcharge de `strings.xml` si elles se voient.
- **iOS** : pas d'app Orneos. Les utilisateurs prennent l'app officielle Nextcloud et se connectent par le code QR de la page Appareils.

## Licence

Les clients Nextcloud sont sous GPL (bureau GPL-2.0+, Android AGPL-3.0/GPL-2.0). Distribuer nos binaires oblige à publier le code correspondant : ce dossier (surcouche + scripts) plus le tag officiel indiqué dans `versions.env`. Les logos Nextcloud (`LicenseRef-NextcloudTrademarks`) ne doivent pas apparaître dans nos builds ; les scripts vérifient leur remplacement.
