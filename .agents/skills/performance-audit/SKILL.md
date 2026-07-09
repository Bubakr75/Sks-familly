# Skill: Audit Performance SKS Family

## Quand utiliser
Quand l'app est lente, quand on ajoute une nouvelle fonctionnalité, ou avant publication.

## Ce que tu fais
1. Cherche les `setState` inutiles (qui rebuildent tout l'écran pour un petit changement)
2. Vérifie les listeners Firestore (trop de listeners = trop de rebuilds)
3. Cherche les images non compressées (base64 sans ImageCompressor)
4. Vérifie les animations (AnimationController bien disposés ?)
5. Cherche les requêtes Firestore qui pourraient être optimisées
6. Vérifie que les `Consumer`/`Selector` sont utilisés au lieu de `Consumer<FamilyProvider>` quand possible
7. Cherche les widgets lourds dans les ListView (manque de `const` ?)
8. Vérifie le temps de démarrage (main.dart : trop d'awaits séquentiels ?)

## Optimisations connues du projet
- BackdropFilter (blur) est coûteux sur web → limiter son usage
- AuroraBackground avec MaskFilter.blur(60) repeint à chaque frame
- Les photos base64 dans Firestore : utiliser ImageCompressor
- Le keep-alive Firestore tourne toutes les 15s

## Commandes utiles
```bash
dart analyze lib/  # Vérifier le code
flutter build web --release  # Tester le build
```
