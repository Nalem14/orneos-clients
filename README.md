# Clients Orneos

Applications Orneos de bureau (Windows, macOS, Linux) et Android (Orneos pour les fichiers, Orneos Meet pour Talk). Ce sont les clients officiels de Nextcloud, **sans fork** : ce dossier ne contient que notre **surcouche** (marque, réglages, icônes) et les scripts qui l'appliquent sur une version officielle précise.

```
versions.env            tags officiels suivis (DESKTOP_TAG, ANDROID_TAG)
brand/                  logo source (mark-1024.svg) ; scripts/make-icons.sh en tire les PNG
desktop/branding.cmake  nom, serveur imposé, flux de mise à jour, GUID Windows
desktop/theme/          icônes et logos qui remplacent ceux de Nextcloud
android/res/            setup.xml (réglages), logos vectoriels, icônes du lanceur
talk/res/               Orneos Meet (nextcloud/talk-android) : setup.xml (serveur, compte partagé, Firebase), icônes
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

## Orneos Meet (Talk Android)

Même principe que l'app Fichiers (`scripts/apply-talk.sh`, saveur `generic`, paquet `eu.orneos.talk`, signé sur le serveur avec la même clé). Il reprend le compte de l'app Orneos (`nc_import_accounts_from` = `eu.orneos.files`, type `eu.orneos`).

**Notifications** : le cloud les envoie lui-même en **Web Push** (app `notifications`, `webpush_enabled`), sans le service de Nextcloud GmbH. Sur le téléphone, le distributeur FCM intégré de la saveur `generic` les reçoit, via **notre projet Firebase** (`orneos-bb6d6`, app `eu.orneos.talk`). Le contenu est chiffré de bout en bout (RFC 8291) : Google ne voit passer que des paquets opaques. La clé d'API n'est pas dans ce dépôt : `apply-talk.sh` l'écrit au build depuis `google-services.json` (`ORNEOS_GOOGLE_SERVICES`, sur le serveur `private/clients/google-services.json`). Elle doit rester restreinte au paquet `eu.orneos.talk` et à l'empreinte de la clé de signature.

## Orneos Meet pour ordinateur (Talk Desktop)

`nextcloud/talk-desktop` (Electron) a un point de branding officiel : `.overrides/build.config.json` (`talk-desktop/build.config.json` : nom, serveur imposé `app.orneos.eu`, identifiants `eu.orneos.meet`, couleurs). `scripts/apply-talk-desktop.sh` le pose et remplace les images de `img/` (générées par `scripts/make-talk-desktop-icons.py`). Construit par la CI (job `meet-desktop` : Windows `.exe`, Mac universel `.dmg` signé « ad hoc », Linux `.zip`). Une fois rebrandé, il ne cherche plus ses mises à jour : la publication prévient ses utilisateurs dans la cloche du cloud.

## Mises à jour des utilisateurs

| | Canal | Côté serveur |
|---|---|---|
| Windows | l'updater intégré télécharge l'installeur (`.exe` NSIS) et l'installe en silence (`/S`) | `/updates/desktop` (`ClientUpdateController`) lit `private/clients/desktop.json` |
| macOS | Sparkle (dans /Applications) : télécharge le DMG et remplace l'app ; signature Ed25519 vérifiée avec `desktop/sparkle-ed25519.pub` (clé privée sur le serveur, `private/clients/sparkle-ed25519.key`, signature automatique à la publication) | même flux, en appcast |
| Linux | notification, lien vers la page Appareils | même flux |
| Android | l'app Fichiers lit `downloads/android/latest` et propose `orneos-<versionCode>.apk` ; les deux apps sont aussi dans **notre dépôt F-Droid** (`https://orneos.eu/downloads/fdroid/repo`, `tools/client-fdroid.sh`), qui les met à jour automatiquement | fichiers statiques |

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
- macOS : la clé Sparkle (`desktop/sparkle-ed25519.pub` et sa moitié privée sur le serveur) ; la changer rendrait les apps installées sourdes aux mises à jour.

## Reste à faire

- **Windows et macOS** : les jobs CI (KDE Craft, mac-crafter) sont à valider au premier passage.
- **Textes** : quelques traductions officielles disent encore « Nextcloud » en dur ; à reprendre par surcharge de `strings.xml` si elles se voient.
- **iOS** : pas d'app Orneos. Les utilisateurs prennent l'app officielle Nextcloud et se connectent par le code QR de la page Appareils.

## Licence

Les clients Nextcloud sont sous GPL (bureau GPL-2.0+, Android AGPL-3.0/GPL-2.0). Distribuer nos binaires oblige à publier le code correspondant : ce dossier (surcouche + scripts) plus le tag officiel indiqué dans `versions.env`. Les logos Nextcloud (`LicenseRef-NextcloudTrademarks`) ne doivent pas apparaître dans nos builds ; les scripts vérifient leur remplacement.
