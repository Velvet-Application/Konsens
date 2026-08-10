# Konsens Revenue — architecture de monétisation

## Objectif

La version gratuite de Konsens reste pleinement utilisable. La monétisation repose sur des formats sponsorisés natifs, un SDK/API B2B et des signaux agrégés. Le produit ne dépend pas d’un réseau publicitaire tiers pour fonctionner.

## Principes produit

- aucune publicité pendant l’inscription ou l’onboarding ;
- aucun interstitiel forcé ;
- ciblage contextuel par placement/catégorie par défaut ;
- `subscription_tier = free` peut recevoir des spots ; `plus` est sans publicité ;
- une campagne doit être explicitement `active` et datée pour être diffusée ;
- sans campagne active, aucun emplacement vide ou faux sponsor n’est affiché ;
- la résolution d’un challenge reste indépendante de l’annonceur ;
- les événements publicitaires utilisent un identifiant de session et ne stockent pas l’adresse IP dans Supabase.

## Inventaire

| Slot | Placement | Usage |
| --- | --- | --- |
| `home_after_hero` | `feed_native` | accueil |
| `challenges_every_fifth` | `feed_native` | flux challenges |
| `challenge_presented_by` | `challenge_sponsor` | sponsoring d’un challenge |
| `post_prediction` | `post_prediction` | après une prédiction |
| `app_contextual_native` | `feed_native` | spot natif Web/PWA actuellement injecté |

## Données Supabase

- `advertisers` : annonceurs ;
- `ad_slots` : inventaire ;
- `ad_campaigns` : ciblage, dates, caps, budget/CPM indicatifs ;
- `ad_creatives` : contenu affiché ;
- `ad_events` : impressions, clics et conversions ;
- `sdk_clients` : clients Konsens Connect et quotas ;
- `sdk_events` : consommation de l’API/SDK.

Les tables commerciales sont protégées par RLS et visibles/modifiables uniquement par l’administration. Les clients Web et SDK passent par des RPC `security definer` à surface réduite.

## API Cloudflare

### Public/app

- `GET /health`
- `GET /v1/config`
- `GET /v1/ads/serve?placement=feed_native&category=sport&session=...`
- `POST /v1/ads/event`

### Konsens Connect

- `GET /v1/signals/challenges/:challengeId`
- `POST /v1/sdk/events`

Les routes Connect exigent `x-konsens-key`. L’origine du navigateur doit correspondre à une origine déclarée pour le client SDK et chaque appel est comptabilisé dans son quota mensuel.

## SDK navigateur

Le fichier public est `public/konsens-connect.js`.

```html
<script src="https://votre-domaine/konsens-connect.js"></script>
<div id="konsens-signal"></div>
<script>
  Konsens.configure({
    apiBase: "https://VOTRE-WORKER-CLOUDFLARE",
    apiKey: "ks_live_..."
  });
  Konsens.mount("#konsens-signal", {
    challengeId: "UUID_DU_CHALLENGE",
    theme: "dark"
  });
</script>
```

## Plans SDK préparés

- Developer : 10 000 événements/mois ;
- Starter : 100 000 ;
- Pro : 1 000 000 ;
- Business : 5 000 000 ;
- Enterprise : quota configurable.

Le tarif commercial n’est pas codé dans l’application : seuls les quotas techniques le sont afin de laisser la politique de prix évoluer sans migration.

## Pilotage

La route `/monetization` est réservée aux rôles `admin`/`moderator`. Elle affiche annonceurs, campagnes actives, impressions, clics/CTR et clients SDK. Elle permet également de générer une clé API client ; la clé brute est affichée une seule fois et seule son empreinte SHA-256 est enregistrée en base.

## Suite prévue

1. ajouter l’éditeur de campagne complet au centre admin ;
2. raccorder les slots `challenge_sponsor` et `post_prediction` lorsque le vrai moteur de challenges/prédictions est visible ;
3. ajouter un fallback Google Ad Manager uniquement lorsqu’aucune campagne directe n’est disponible ;
4. intégrer le même contrat de diffusion dans l’application iOS ;
5. ajouter facturation et comptage commercial au-dessus de `sdk_events`.
