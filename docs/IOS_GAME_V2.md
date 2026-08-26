# KONSENS iOS · Game V2

## UX active

- Interface de jeu épurée : score, challenge principal, action, ligue.
- Mascotte graphique retirée de l'application ; seules les interventions texte `K` restent actives.
- Profil jeu sans Academy ni Blockchain.
- KONSENS+ met en avant le mode sans publicité.

## Publicité iOS

La cible iOS intègre Google Mobile Ads via Swift Package Manager.

En développement, la mise utilise l'identifiant officiel Google d'annonce récompensée de test. Un joueur gratuit choisit `REGARDER LA PUB & MISER`; la mise n'est envoyée qu'après le callback de récompense. Les comptes Premium sautent cette étape.

Le service publicitaire recharge en avance l'annonce suivante afin de conserver une boucle de jeu fluide entre deux mises.

Avant publication App Store : remplacer l'App ID et l'Ad Unit ID de test par les identifiants AdMob KONSENS et finaliser la gestion du consentement publicitaire.
