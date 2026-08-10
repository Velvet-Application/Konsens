# Konsens

Konsens est une arène sociale de stratégie financière et de prédiction, sans argent réel ni conversion des crédits. Le dépôt regroupe le Web mobile/PWA, l’application iOS native, le schéma Supabase et la passerelle Cloudflare.

## Structure

- `app/` : Web mobile/PWA déployé sur Cloudflare.
- `ios/` : projet Xcode SwiftUI, iOS 17 minimum.
- `supabase/migrations/` : modèle PostgreSQL, RLS, ledger et transactions atomiques.
- `cloudflare/` : API publique, CORS, configuration et tâches planifiées.
- `.github/workflows/` : qualité Web, compilation iOS, déploiement Worker et archive TestFlight.

## Démarrage Web

```bash
npm ci
npm run dev
```

## iOS

Ouvrir `ios/Konsens.xcodeproj`, choisir l’équipe Apple dans Signing & Capabilities, puis lancer la cible `Konsens` sur un iPhone. La version actuelle fonctionne avec un jeu de données de démonstration afin de permettre les essais avant le raccordement au projet Supabase dédié.

## Principes de sécurité

- aucune clé de service dans les clients ;
- RLS sur toutes les tables exposées ;
- ordres idempotents ;
- traitement atomique des ordres par trigger privé ;
- ledger accessible en lecture seulement ;
- crédits non achetables et non convertibles.
