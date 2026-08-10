# Konsens iOS

Le projet Xcode contient désormais le parcours d’authentification Supabase, l’inscription par mail, Apple et Google, puis la collecte du pseudo et des données privées.

## Ouvrir et tester

1. Ouvrir `Konsens.xcodeproj` dans Xcode 16 ou supérieur.
2. Attendre la résolution automatique du package `supabase-swift`.
3. Dans **Signing & Capabilities**, sélectionner l’équipe Apple et ajouter **Sign in with Apple**.
4. Vérifier que le Bundle ID reste `com.konsens.beta`.
5. Dans Supabase, autoriser le callback `konsens://auth-callback`.
6. Sélectionner un simulateur iPhone et lancer avec `⌘R`.

La clé intégrée est une clé publique Supabase. Aucune clé `service_role`, OpenAI ou fournisseur financier ne doit être ajoutée au projet iOS.

Ouvrir `Konsens.xcodeproj` dans Xcode 16 ou ultérieur, sélectionner l’équipe de signature, puis lancer la cible `Konsens` sur un iPhone sous iOS 17 minimum. La bêta fonctionne immédiatement avec les données de démonstration. Le branchement Supabase sera activé via `Config.xcconfig` sans placer de clé secrète dans le dépôt.
