# KONSENS Mascot — canonical USDZ specification

Status: **LOCKED CANON**

This document defines the production contract for the Konsens leprechaun mascot. Any future 3D export must preserve the approved character identity; an approximate or generic leprechaun is not acceptable.

## Canonical identity

- Mischievous, charming, cocky leprechaun mascot.
- Bright green eyes, warm orange/red hair and beard, pointed ears, expressive eyebrows.
- Tall emerald-green top hat with black band, gold buckle and gold `K` emblem.
- Emerald-green suit with gold piping/buttons, dark waistcoat, white shirt and green bow tie.
- Belt buckle marked `K`, green trousers, striped socks, green shoes with gold buckles.
- Gold `KONSENS / K / KOINS` coin is a separate rigged prop.
- Premium stylised mobile-game 3D rendering; never photorealistic and never childish/chibi enough to alter the approved proportions.

The image asset `KonsensMascotFallback` in `Assets.xcassets` is the in-app visual identity fallback and must remain consistent with the final mesh.

## Required file

Final bundle resource name:

`KonsensMascot.usdz`

The app's RealityKit runtime looks for exactly this resource name.

## Rig requirements

Minimum skeleton:

- root / hips / spine / chest / neck / head
- jaw
- left/right eyes or eye aim controls
- eyebrows / eyelids through blend shapes or facial joints
- shoulders / upper arms / forearms / hands / fingers sufficient for pointing and holding the coin
- thighs / calves / feet
- hat parented to head
- coin prop socket on hand plus detachable coin entity

Facial rig must support at least:

- neutral smile
- broad smile
- smirk
- laugh/open mouth
- wink left/right
- eyebrow raise
- mock-disappointed / loss face

## Animation clips

RealityKit searches clip names by substring, so these canonical clip names should be used exactly when possible:

1. `idle_breath`
2. `wave_welcome`
3. `peek_appear`
4. `laugh_chuckle`
5. `tease_point_wink`
6. `coin_toss`
7. `celebrate_victory`
8. `lose_coin_disappear`
9. `shrug_no_money`

Optional recommended clips:

- `facepalm`
- `look_left`
- `look_right`
- `nod_yes`
- `shake_no`
- `dance_short`
- `jackpot`
- `league_taunt`

## Behaviour contract

- Opening: full-body `wave_welcome` + direct greeting.
- Random presence: `peek_appear`, `tease_point_wink`, `laugh_chuckle`.
- Bet placed: `coin_toss`.
- Investment: `tease_point_wink` or calm confident gesture.
- Gain: `celebrate_victory`, coin visually amplified.
- Loss: `lose_coin_disappear`, coin falls/fades/disappears.
- Insufficient balance / rejected action: `shrug_no_money`.
- League/navigation: teasing expressions and pointing/looking toward UI content.

## Runtime constraints

- iOS 17+ RealityKit.
- Target iPhone portrait first, including iPhone 17 Pro Max.
- Character should read clearly between ~150 pt cameo size and ~390 pt opening size.
- Transparent background; no baked environment.
- Lighting must work with app-side key/fill lights.
- Avoid excessive polygon count or 4K textures for mobile. Aim for a performant hero-game character rather than cinematic geometry.
- All materials must be embedded or referenced inside the USDZ package.
- No external network asset dependency.

## Acceptance criteria

The USDZ is accepted only if:

- face is immediately recognisable as the approved Konsens mascot;
- front/3-quarter/side/back proportions stay coherent;
- outfit details and K branding remain intact;
- smile/smirk/wink/laugh preserve his personality;
- all nine required animations play in RealityKit;
- coin prop can visibly appear/disappear/toss without breaking the rig;
- Xcode app build succeeds and the model renders correctly on a physical iPhone.

Anything visually approximate remains a prototype, not the final mascot.
