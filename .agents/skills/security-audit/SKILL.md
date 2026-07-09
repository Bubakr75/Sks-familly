# Skill: Audit Sécurité SKS Family

## Quand utiliser
Quand on demande un audit de sécurité, une vérification des règles Firestore, ou avant une publication.

## Ce que tu fais
1. Vérifie `firestore.rules` : toutes les règles doivent utiliser `request.auth != null` (jamais `if true`)
2. Vérifie `storage.rules` : même chose
3. Cherche les secrets en dur dans le code (clés API, mots de passe)
4. Vérifie que `.gitignore` protège les fichiers sensibles
5. Vérifie que le PIN parent est haché (SHA-256 minimum)
6. Vérifie que les photos ne contiennent pas de données EXIF sensibles
7. Lance `dart analyze` et rapporte les warnings critiques

## Format de rapport
Pour chaque point : ✅ OK / ⚠️ À corriger / ❌ Bloquant
Avec le fichier et la ligne concernés.

## Contexte du projet
- App Flutter avec Firebase (Firestore, Auth anonyme, Storage, Functions)
- PIN parent haché SHA-256 dans SharedPreferences
- Photos en base64 compressé dans Firestore
- Cloud Functions dans functions/index.js
