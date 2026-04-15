# Content Author Reference

This document explains how to create game content using only YAML and image files,
without touching any GDScript code.

---

## Portraits

Drop PNG images into `assets/portraits/` with a filename matching the visitor's
`portrait` field. The code loads them automatically.

```
assets/portraits/farmer_grig.png
assets/portraits/guard_roderick.png
assets/portraits/witch_mara.png
assets/portraits/sage.png
```

In your YAML visitor definition, reference the portrait by its filename (without extension):

```yaml
- id: visitor_fermer_day1
  name: Farmer Grig
  portrait: farmer_grig    # loads assets/portraits/farmer_grig.png
```

If no matching image is found, a colored placeholder with the first letter of the
visitor's name is shown instead.

The legacy `sprite` field is still supported as a fallback, but `portrait` takes
priority.

---

## Visitor YAML Structure

Each day's visitors live in `content/visitors/day_XX.yaml`:

```yaml
visitors:
  - id: unique_visitor_id          # required, unique string
    name: "Display Name"           # shown in the UI
    portrait: portrait_key         # matches filename in assets/portraits/
    importance: low                # low | medium | high | critical
    condition:                     # optional, gates visibility
      require_flags:               # ALL must be set for visitor to appear
        - flag_name
      forbid_flags:                # NONE may be set for visitor to appear
        - other_flag
    dialogue:                      # optional pre-question conversation
      - speaker: visitor
        text: "Hello, sage."
      - speaker: sage
        text: "Welcome."
    question_text: >
      The visitor's main question text.
    helpful_knowledge:
      - knowledge_key_1
    without_knowledge_hint: >
      Hint shown when the player has no relevant knowledge.
    answers:
      - id: a1
        text: "Answer text shown to the player"
        outcome: best              # best | good | neutral | bad
        requires_knowledge:
          - knowledge_key_1
        city_effect:
          prosperity: 3
          morale: 1
        # See "Answer Presets" below for more options
```

---

## Answer Presets

Each answer can include any combination of these preset directives:

### city_effect
Changes city stats immediately when the answer is chosen.

```yaml
city_effect:
  prosperity: 3
  morale: -1
  trust: 2
  safety: -2
```

Stats are clamped to 0-100.

### consequence_event
Triggers a consequence event (city walk scene, visitor, or notification) after a delay.

```yaml
consequence_event: farmer_witch_peace   # ID from consequences.yaml
```

### return_day / return_text / return_city_effect
Schedules the visitor to return after N days with a message and optional stat changes.

```yaml
return_day: 3
return_text: >
  Thank you, sage! Everything worked out.
return_city_effect:
  prosperity: 2
```

### set_flags
Sets story flags that can be checked later by `condition.require_flags` / `condition.forbid_flags`.

```yaml
set_flags:
  - witch_is_friendly
  - farmer_helped
```

### remove_flags
Removes previously set story flags.

```yaml
remove_flags:
  - witch_hostile
```

### inject_visitors
Adds a visitor to appear on a specific future day. The visitor must be defined
in the corresponding `day_XX.yaml` file (with a `condition` to normally hide it)
or in `content/visitors/conditional.yaml`.

```yaml
inject_visitors:
  - visitor_id: visitor_witch_day4
    day: 4
```

### remove_visitors
Prevents a visitor from appearing on any future day.

```yaml
remove_visitors:
  - visitor_witch_angry_day3
```

### swap_visitors
Replaces one visitor with another on a specific day.

```yaml
swap_visitors:
  - original: visitor_merchant_default
    replacement: visitor_merchant_grateful
    day: 3
```

### add_consequence
Schedules a new consequence to trigger after a delay (in days from today).

```yaml
add_consequence:
  - event_id: witch_herbs_at_market
    delay: 2
```

---

## Consequences (consequences.yaml)

Consequences are events triggered by visitor answers or other consequences.
They live in `content/events/consequences.yaml`.

### city_walk type
Shows a scene at a location in the city walk view.

```yaml
consequences:
  - id: farmer_witch_peace
    trigger_delay: 2               # days after the triggering event
    type: city_walk
    location: market               # market | gates | temple | smithy | tavern
    portrait: farmer_grig          # optional, shows portrait in event overlay
    scene_text: >
      Description of what the player sees.
    npc_dialogue: >
      What the NPC says.
    city_state_change:
      prosperity: 2
      trust: 1
    # Consequences can also include presets:
    set_flags:
      - market_thriving
    inject_visitors:
      - visitor_id: visitor_herb_merchant
        day: 5
```

### visitor type
Injects a visitor on the trigger day (auto-triggered at day start).

```yaml
  - id: witch_thanks
    trigger_delay: 3
    type: visitor
    visitor_id: visitor_witch_thanks   # must exist in day files or conditional.yaml
```

### notification type
Shows a text popup at day start.

```yaml
  - id: plague_warning
    trigger_delay: 1
    type: notification
    title: "News from the road"
    text: "Travelers report sickness spreading..."
    set_flags:
      - plague_rumor
```

---

## Conditional Visitors

Visitors with a `condition` block only appear when the flag requirements are met:

```yaml
visitors:
  - id: witch_grateful_day3
    name: Witch Mara
    portrait: witch_mara
    condition:
      require_flags:
        - witch_peace_path        # must be set
      forbid_flags:
        - witch_attack_path       # must NOT be set
    question_text: "I want to help..."
    answers:
      - id: accept
        text: "Welcome"
        set_flags:
          - witch_in_city
```

Visitors without a `condition` block always appear (unless removed by a preset).

---

## Conditional Visitors File (optional)

For visitors that can appear on any day when injected, create
`content/visitors/conditional.yaml`:

```yaml
conditional_visitors:
  - id: visitor_witch_day4
    name: Witch Mara
    portrait: witch_mara
    dialogue: [...]
    question_text: "..."
    answers: [...]
```

---

## Story Flags

Flags are simple strings stored in the game state. They persist across days
and are saved/loaded with the game.

- Set via `set_flags` in answers or consequences
- Removed via `remove_flags`
- Checked via `condition.require_flags` (all must be present) and
  `condition.forbid_flags` (none may be present)

Common patterns:
- Use `_path` suffix for branching storylines: `witch_peace_path`, `witch_attack_path`
- Use descriptive names: `market_thriving`, `plague_rumor`, `witch_in_city`

---

## Day / Consequence Timing

- Day 1 is the starting day
- `return_day: 3` means the visitor returns 3 days after today
- `trigger_delay: 2` means the consequence fires 2 days after being scheduled
- `inject_visitors` with `day: 4` injects on absolute day 4
- The game checks for endings after day 7 (MAX_DAYS)

---

## Common Recipes

### Branching storyline across days

```yaml
# day_01.yaml - farmer asks about sick crops
answers:
  - id: peace
    text: "Go talk to the witch peacefully"
    set_flags: [witch_peace_path]
    inject_visitors:
      - visitor_id: witch_grateful_day3
        day: 3

  - id: attack
    text: "Drive the witch out"
    set_flags: [witch_attack_path]
    remove_visitors: [witch_grateful_day3]
```

```yaml
# day_03.yaml - witch only appears on peace path
visitors:
  - id: witch_grateful_day3
    name: Witch Mara
    portrait: witch_mara
    condition:
      require_flags: [witch_peace_path]
      forbid_flags: [witch_attack_path]
    question_text: "I want to help..."
```

### Chain of consequences

```yaml
# Answer triggers a consequence that triggers another consequence
answers:
  - id: a1
    text: "Help the merchant"
    consequence_event: merchant_grateful
    set_flags: [helped_merchant]

# In consequences.yaml
  - id: merchant_grateful
    trigger_delay: 1
    type: city_walk
    location: market
    set_flags: [market_improved]
    add_consequence:
      - event_id: merchant_brings_friend
        delay: 2
```
