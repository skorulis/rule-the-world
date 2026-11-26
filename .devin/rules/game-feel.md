# Game feel: build game UI, not app UI

Rule the World is a territory-capture game, not a utility app. New screens,
rewards, and interactions must feel like a game — juicy, animated, tactile —
not like iOS Settings. When adding or modifying user-facing content, apply
these guidelines before reaching for stock components.

## Avoid "app-like" patterns

- Do not present rewards, captures, or achievements with plain `alert()`s —
  use the reveal ceremony (`RewardRevealView` in `Scene/Rewards/`) or an
  equivalent full-screen moment with animation, glow, and haptics.
- Do not build screens that are only `List`/`LabeledContent` rows of raw
  numbers. Show progress visually: bars (you vs. rival), rank icons and
  progress, stat blocks, charts.
- Do not leave state changes instant and silent — a capture, purchase, or
  win deserves visible/motion feedback.

## Prefer game patterns already in the codebase

- Rarity is a visual language: use `Rarity.color`, gradients, and glows like
  `PowerUpCard`/`PowerUpIcon` (border gradient, tinted fill, shadow for
  epic+) rather than text labels.
- Rewards use `RewardRevealView` (`Scene/Rewards/`): `opening` phase masks
  the server round trip with a looping animation, `revealed` springs the
  reward card in with confetti and a `.success` haptic. Reuse it for any
  new "you got something" moment; keep a minimum opening duration so fast
  responses still read as a reveal.
- Haptics: light tic (`UIImpactFeedbackGenerator(.light)`) for routine
  feedback, `UINotificationFeedbackGenerator().notificationOccurred`
  for wins. Inject a `CaptureHaptics`-style abstraction so tests can spy.
- Map animations: follow `HexGridOverlayRenderer`'s patterns — flips pop
  with a `sin(progress·π)` scale pulse, captures add an expanding ring.
  Reuse the `CADisplayLink` driver for any looping/pulsing effects.
- Player-facing color: owned territory is blue, rivals red — keep the
  player's color distinctive and consistent across map, cards, and reveals.

## Checklist for new UI

1. Does the moment animate? (spring entrance, pulse, pop, particles)
2. Does it vibrate? (haptic on capture/win/reward)
3. Does it glow? (accent/rarity-colored radial gradient or shadow)
4. Does it celebrate? (win states get ceremony, not a plain OK button)
5. Would it look at home in a game? If it looks like a settings screen,
   rework it.
