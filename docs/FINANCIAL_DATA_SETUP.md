# Flux financiers publics — mise en service

Konsens ne doit jamais afficher de cours inventé. Tant qu’aucun fournisseur n’est configuré, l’interface reste vide.

## Architecture recommandée

- **Marchés cotés** : Twelve Data ou Finnhub pour les actions, ETF, indices et devises.
- **Cryptoactifs** : CoinGecko pour les prix et l’historique ; Alchemy pour les mouvements blockchain en temps réel.
- **Vérification** : conserver pour chaque valeur le fournisseur, l’horodatage, la devise et l’identifiant externe.
- **Stockage** : écrire les observations dans `price_history`; le client Web et iOS lit Supabase et ne contacte jamais directement les fournisseurs.

## Étapes

1. Créer les comptes fournisseur au nom de Konsens et vérifier les droits d’utilisation commerciale des données.
2. Générer les clés API côté fournisseur.
3. Dans Supabase, ajouter les secrets `MARKET_DATA_API_KEY`, `COINGECKO_API_KEY`, `ALCHEMY_API_KEY` et `ALCHEMY_WEBHOOK_SIGNING_KEY`. Ne jamais mettre une clé privée dans le Web ou dans Xcode.
4. Créer un webhook Alchemy « Address Activity » pointant vers `https://mxuevsspybxoovsutsbs.supabase.co/functions/v1/blockchain-webhook`.
5. Programmer une Edge Function d’import des cours toutes les 5 minutes pendant les heures d’ouverture des marchés. Utiliser l’upsert `(asset_id, observed_at)` et conserver la réponse brute dans un journal technique privé.
6. Refuser une observation trop ancienne : 15 minutes pour les marchés, 5 minutes pour les cryptoactifs. Afficher « Donnée indisponible » au lieu de réutiliser silencieusement une ancienne valeur.
7. Comparer chaque nuit un échantillon de clôtures avec une seconde source. Une divergence supérieure au seuil défini bloque la publication et crée une alerte administrateur.

## Génération IA quotidienne

L’Edge Function `generate-daily-challenges` est déployable mais reste inactive sans `OPENAI_API_KEY` et `CHALLENGE_CRON_SECRET`. Elle utilise la recherche Web et un schéma JSON strict, puis écrit uniquement des brouillons dans `challenge_drafts`. Aucun challenge ne doit être publié sans validation humaine de la question, de la source, de la date de clôture et de la règle de résolution.

## Apple et Google

- Activer Google et Apple dans **Supabase > Authentication > Providers**.
- Google : créer un client OAuth Web et un client iOS, puis renseigner les URI de redirection affichées par Supabase.
- Apple : activer « Sign in with Apple » pour l’App ID `com.konsens.beta`, créer un Services ID pour le Web et un secret Apple, puis les renseigner dans Supabase.
- Ajouter l’URL publique de Konsens et le schéma iOS `konsens://auth-callback` aux URL de redirection autorisées.
