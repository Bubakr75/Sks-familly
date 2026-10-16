# Préparation Android Google Play

Cette étape ajoute un AAB signé au workflow existant sans changer la version
4.8.13+526, le package ou les secrets de signature. La publication APK est réalisée par le workflow de Release après autorisation.

Le build cible API 36. Le manifeste final extrait du bundle est contrôlé avec
bundletool 1.18.3 : package, versionName, versionCode, targetSdk et permissions.
Le bundle est validé par bundletool et jarsigner ; son certificat doit correspondre
à celui de l'APK officiel déjà vérifié par le workflow. Un inventaire des permissions
est conservé dans play-bundle-report.json. REQUEST_INSTALL_PACKAGES est bloqué.
Les autres permissions restent à auditer ; leur présence n'est pas une validation Play.

L'AAB et le rapport sont conservés sept jours comme artefacts Actions uniquement
si le dépôt est privé, jamais ajoutés aux fichiers de la Release. Sur le dépôt
public actuel, le bundle est construit et contrôlé mais son téléversement est
désactivé. Utiliser un dépôt Actions privé pour sa conservation confidentielle.

## Validation restante

- Exécuter un build signé autorisé dans GitHub Actions pour vérifier le vrai AAB.
- Vérifier toutes les permissions et les bibliothèques natives, notamment 16 Ko.
- Auditer caméra, microphone, alarmes exactes et déclarations Android TV.
- Décider si Android TV doit être conservé avant de retirer ses déclarations.
- Préparer confidentialité, suppression de compte et déclarations Familles.
- Décider de la stratégie Play App Signing avec la clé existante.
- Tester via un canal interne Play avant toute production.

Le workflow existant publie aussi des APK lors d'un tag ou d'un lancement manuel.
Ne pas le déclencher pour un simple audit. Le contrôle de version impose un
versionCode supérieur à la dernière Release ; le numéro actuel reste inchangé
tant que la préparation globale n'est pas terminée.

Sources :
- https://developer.android.com/google/play/requirements/target-sdk
- https://developer.android.com/tools/bundletool
