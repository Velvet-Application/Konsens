# Konsens

Konsens est une arène sociale de stratégie financière et de prédiction, sans argent réel ni conversion des crédits. Le dépôt regroupe le Web mobile/PWA, l’application iOS native, le schéma Supabase et la passerelle Cloudflare.

## Structure

- `app/` : Web mobile/PWA déployé sur Cloudflare.
- `ios/` : projet Xcode SwiftUI, iOS 17 minimum.
- `supabase/migrations/` : modèle PostgreSQL, RLS, ledger, monétisation et transactions atomiques.
- `cloudflare/` : API publique, CORS, configuration, Konsens Connect et tâches planifiées.
- `public/konsens-connect.js` : SDK navigateur Konsens Connect.
- `.github/workflows/` : qualité Web, compilation iOS, déploiement Worker et archive TestFlight.

## Démarrage Web

```bash
npm ci
npm run dev
```

## Monétisation

La version gratuite est préparée pour des spots sponsorisés natifs/contextuels et pour `Konsens Connect`, le SDK/API B2B de diffusion des signaux de prédiction. Le centre de pilotage admin est disponible sur `/monetization`. Les détails techniques et règles produit sont documentés dans `docs/MONETIZATION.md`.

## iOS

Ouvrir `ios/Konsens.xcodeproj`, choisir l’équipe Apple dans Signing & Capabilities, puis lancer la cible `Konsens` sur un iPhone. La version actuelle fonctionne avec un jeu de données de démonstration afin de permettre les essais avant le raccordement au projet Supabase dédié.

## Principes de sécurité

- aucune clé de service dans les clients ;
- RLS sur toutes les tables exposées ;
- clés Konsens Connect stockées uniquement sous forme d’empreinte SHA-256 ;
- ordres idempotents ;
- traitement atomique des ordres par trigger privé ;
- ledger accessible en lecture seulement ;
- crédits non achetables et non convertibles.
