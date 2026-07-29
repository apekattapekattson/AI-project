# Deep Delve: Forge Empire
### Complete design document for a Roblox incremental game

> Deliberately conventional. No gimmick. Every system here is one players already
> understand from other incrementals — the goal is execution quality, pacing, and
> a structure that accepts new content for years without redesign.

---

## 1. Elevator pitch

You start with a rusty pickaxe and one dirt tile. You mine ore, haul it to a
furnace, smelt it into bars, and sell the bars for Coins. Coins buy better picks,
faster furnaces, more haulers, and deeper mine layers. Eventually you stop swinging
the pick yourself entirely — drills mine, conveyors haul, furnaces run themselves,
and you watch the numbers climb.

When progress slows, you **Delve**: reset your mine, keep nothing but permanent
**Cores**, and restart with a multiplier that makes the first two hours collapse
into ten minutes. Deeper Delves unlock new mine layers, new ore types, and
eventually a second prestige layer — **Ascension** — that converts total lifetime
Cores into permanent structural perks.

It is "numbers go up," polished, with a satisfying tactile mining loop at the front
and a deep automation/optimization game behind it.

---

## 2. Gameplay loop

**The 30-second loop (early):**
1. Click/swing at an ore node → node yields raw ore into your backpack
2. Backpack fills → walk to furnace → deposit
3. Furnace smelts over time → produces bars
4. Sell bars at the Trader → Coins
5. Spend Coins on the nearest affordable upgrade
6. Repeat, but 15% faster

**The 5-minute loop (mid):**
Buy a drill → it mines a node automatically. Buy a conveyor → it hauls to the
furnace. Buy an auto-seller → bars become Coins without you. Your job shifts from
*performing* the loop to *configuring* it: which ore to prioritize, which furnace
tier to feed, where to place the next conveyor.

**The 45-minute loop (late):**
Push down a mine layer, hit a wall where ore value can't keep up with upgrade cost
scaling, evaluate whether to Delve now or grind 20 more minutes for one more layer.
Delve. Rebuild in 8 minutes what took 90. Push past where you were.

**The multi-session loop:**
Log in → collect AFK earnings → claim daily → clear 3 daily quests → push one
milestone → log off. Weekly goals and event tracks span sessions.

---

## 3. Core mechanics

### Mining
Ore nodes have **HP**. Your pickaxe has **Damage** and **Swing Speed**. Node HP
scales per layer; pick damage scales with upgrades. A node broken yields
`base_yield × luck_roll` raw ore. This is the tactile hook — it must feel good:
screen shake, chunk particles, a rising pitch on consecutive hits, a satisfying
crack on break.

### Hauling
**Backpack capacity** gates early play deliberately. Full backpack = forced walk to
the furnace. This creates the first meaningful upgrade decision (capacity vs.
damage) and makes the first conveyor purchase feel like liberation.

### Smelting
Furnaces convert `N raw ore → 1 bar` over `T seconds`. Furnace tiers improve ratio
and speed. Different ores require minimum furnace tiers — this gates layer progress
behind infrastructure, not just Coins.

### Selling
Bars sell for Coins. Bar value is the primary lever designers pull when adding new
layers; it scales exponentially by ore tier.

### The four verbs
Every system in the game is one of: **Mine** (produce), **Haul** (move),
**Smelt** (transform), **Sell** (realize value). New content is always a new
instance of one of these four — which is exactly why the game is expandable.

---

## 4. Progression overview

| Phase | Duration | Player state |
|---|---|---|
| **Early** | 0:00 – 0:45 | Manual mining. Layers 1–3 (Dirt, Stone, Copper). First drill ~12 min, first conveyor ~25 min. Backpack pain is the core tension. First Delve available ~40 min. |
| **Mid** | 0:45 – 2:30 | Delves 1–5. Automation covers ~70% of the loop. Layers 4–8 (Iron → Gold). Core upgrade tree opens. Quests and achievements become a meaningful income stream. |
| **Late** | 2:30 – 5:00 | Delves 6–15. Full automation; the game is now about throughput ratios and layer-push optimization. Layers 9–12 (Platinum → Obsidian). Second currency (**Shards**) from deep-layer rare nodes. |
| **Endgame** | 5:00+ | **Ascension** unlocks at Delve 15. Converts lifetime Cores → Ascension Points → permanent structural perks (extra furnace slots, offline rate, layer skip). Layers 13–16 and the Rift challenge layers. |

**Meaningful progression before endgame: ~5.5–6.5 hours** for a median player, with
optimized play around 4.5 and casual play around 9. That range is intentional.

**Pacing rule:** the time-to-next-meaningful-purchase should never exceed ~90
seconds in early game, ~4 minutes in mid, ~12 minutes in late. When it does, a
prestige reset must be available and clearly signposted.

---

## 5. Upgrade systems

Three separate trees, deliberately kept distinct so each prestige layer has
something to own.

### A. Coin upgrades (reset on Delve)
Bought constantly, cheap, incremental. Cost curve `cost = base × 1.15^n`.

- Pick Damage, Swing Speed, Backpack Capacity, Luck
- Furnace Speed, Furnace Ratio, Furnace Slots
- Walk Speed, Auto-Sell Rate, Conveyor Speed
- Drill Count, Drill Damage

### B. Core upgrades (permanent, reset only on Ascension)
Bought rarely, expensive, chunky. Cost curve `cost = base × 2.4^n`, tiers capped at
10–25 levels each. These are the "I made real progress" purchases.

- **Starting Kit** — begin each Delve with tier-N pick and furnace
- **Core Multiplier** — global ore yield ×
- **Offline Efficiency** — AFK rate %
- **Layer Memory** — start each Delve N layers down
- **Automation Retention** — keep X drills through Delve
- **Shard Fortune** — rare node spawn rate

### C. Ascension perks (permanent forever)
Small in number, large in impact, unlocked one at a time. Structural changes, not
multipliers — this keeps them feeling different from Cores.

- +1 furnace slot (max +4)
- Conveyors ignore distance penalty
- Delve requirement reduced 20%
- Offline cap 8h → 24h
- Unlock a passive second mine that runs while you're in the first

**Design rule:** never let two trees both sell "yield ×". Each tree must feel
categorically different or prestige stops being exciting.

---

## 6. Rebirth / prestige design

### Layer 1 — Delve
- **Unlocks at:** 100,000 total Coins earned
- **Resets:** Coins, Coin upgrades, drills, conveyors, mine layer progress
- **Keeps:** Cores, Core upgrades, achievements, collections, quests, cosmetics
- **Grants:** `Cores = floor( (LifetimeCoinsThisRun / 1e5) ^ 0.55 )`

The `^0.55` exponent is the single most important number in the game. Below ~0.5,
long runs feel pointless. Above ~0.6, players over-extend and stall. It should be a
config value and tuned against live data.

### Layer 2 — Ascension
- **Unlocks at:** Delve 15 **and** 1e9 lifetime Cores
- **Resets:** everything Delve resets, plus Cores and Core upgrades
- **Keeps:** Ascension perks, achievements, collections, cosmetics, stats
- **Grants:** `AP = floor( (LifetimeCores / 1e9) ^ 0.5 )`

### Layer 3 — reserved
Deliberately left unbuilt. The economy is specified so a third layer
(**Convergence**) can be inserted at 1e14 lifetime AP without touching layers 1–2.
This is the "don't require a redesign in year two" insurance policy.

**Prestige UX is non-negotiable:** a permanent HUD element showing *exactly* how
many Cores you'd earn right now, and a projection of what your next-run speed would
be. Players should never have to open a wiki to know if resetting is correct.

---

## 7. Economy

### Currencies

| Currency | Source | Sink | Resets on |
|---|---|---|---|
| **Coins** | Selling bars | Coin upgrades, layer unlocks | Delve |
| **Cores** | Delve | Core upgrades | Ascension |
| **Shards** | Rare deep-layer nodes | Cosmetics, reroll quests, event track | Never |
| **Ascension Points** | Ascension | Ascension perks | Never |
| **Robux** | Purchase | Gamepasses, dev products | — |

**Shards are the anti-frustration currency.** They're earned slowly, never reset,
and buy things that don't affect power. They give a losing session a floor.

### Scaling
- Upgrade cost: `base × 1.15^n` (standard, readable, players can eyeball it)
- Ore value by layer: `base × 3.2^layer`
- Node HP by layer: `base × 2.9^layer`

Value grows slightly faster than HP (3.2 vs 2.9), so each new layer is a genuine
income increase *if* you have the pick damage to break its nodes. That gap is the
entire pacing mechanism: too wide and layers trivialize the game, too narrow and
pushing down feels bad. Keep it between 1.08× and 1.14× ratio.

### Inflation control
1. **Prestige exponents < 1** — the primary brake. Sub-linear returns on every reset.
2. **Soft caps** — Luck, Swing Speed and Offline Efficiency use
   `effective = cap × (1 - e^(-x/cap))`. Approaches a limit, never blocks purchase.
3. **Hard caps** — only where required for stability: Swing Speed 20/sec (network),
   Drill Count 50 (performance), Furnace Slots 12 (UI).
4. **Layer gates** — a layer requires a minimum furnace tier, so Coins alone can
   never skip content.
5. **No currency conversion between layers** — Coins can never buy Cores. This is
   what prevents an exploit in one system from destroying the whole economy.

### Long-term balance
All curve constants live in one `EconomyConfig` ModuleScript. Rebalancing is a
config edit and a version bump, never a code change. Track median
time-to-first-Delve weekly — if it drifts outside 35–50 minutes, the early curve
needs attention.

---

## 8. Worlds / areas

Sixteen **layers** in one continuous vertical shaft, grouped into four **zones**.
Vertical continuity matters: players can see how far they've come by looking up.

| Zone | Layers | Ores | Gate |
|---|---|---|---|
| **Surface Quarry** | 1–4 | Dirt, Stone, Copper, Coal | — |
| **Iron Depths** | 5–8 | Iron, Silver, Gold, Ruby | Furnace T2, Delve 2 |
| **Molten Reach** | 9–12 | Platinum, Titanium, Diamond, Obsidian | Furnace T4, Delve 6 |
| **The Rift** | 13–16 | Voidstone, Starmetal, Aether, Singularity | Furnace T6, Ascension 1 |

Each zone has its own art palette, ambient audio, hazard (heat, gas, void
instability) mitigated by an equipment upgrade, and one unique rare node type.

**Expansion slot:** zone 5 (**The Core**, layers 17–20) is specced and unbuilt.
Adding it requires only config entries plus art — the shaft is built to extend.

---

## 9. Automation systems

Automation is unlocked progressively so the player *feels* each hand-off.

1. **Drill** (~12 min) — auto-mines one node. First taste.
2. **Conveyor** (~25 min) — auto-hauls ore to furnace. Kills the backpack walk.
3. **Auto-Smelt** (Delve 1) — furnace refills itself from the conveyor.
4. **Auto-Sell** (Delve 2) — bars → Coins with no input.
5. **Auto-Buy** (Delve 4) — set a rule: "always buy cheapest upgrade." A quality-of-
   life gift that respects the player's time.
6. **Drill Foreman** (Delve 8) — drills retarget to the highest-value reachable node.
7. **Layer Crawler** (Ascension 2) — slowly auto-pushes mine layers while offline.

**Offline / AFK:** offline earnings run at Core-upgraded efficiency (base 25%,
max 70%), capped at 8h (24h with Ascension perk). Calculated server-side from
`lastLogoutTimestamp` against a rate snapshot saved at logout — never recomputed
from client-claimed elapsed time.

---

## 10. Technical architecture

### Principles
- **Server is authoritative for all currency, all purchases, all progression.**
  The client renders and requests; it never asserts state.
- **Modular services.** Each system is a ModuleScript with `:Init()` and `:Start()`,
  loaded by a single bootstrapper. No cross-requiring between services except
  through a service locator.
- **Config is data, not code.** All tunables in ModuleScripts returning plain tables.

### Structure
```
ServerScriptService/
  Bootstrap.server.lua
  Services/
    ProfileService.lua      -- session-locked save/load
    EconomyService.lua      -- currency mutation, single source of truth
    MiningService.lua       -- node HP, yield rolls, validation
    SmeltService.lua        -- furnace ticks
    AutomationService.lua   -- drills, conveyors, auto-buy
    PrestigeService.lua     -- Delve / Ascension
    QuestService.lua
    OfflineService.lua
    AnalyticsService.lua
ReplicatedStorage/
  Config/
    EconomyConfig.lua       -- curve constants
    LayerConfig.lua         -- 16 layers, extensible array
    UpgradeConfig.lua
    QuestConfig.lua
  Remotes/
  Shared/
    BigNumber.lua           -- mantissa+exponent, values exceed 2^53
    Formatter.lua           -- 1.23K / 4.56M / 7.89aa
StarterPlayerScripts/
  Controllers/
    InputController.lua
    UIController.lua
    EffectsController.lua
```

### Client/server split

| Client | Server |
|---|---|
| Swing animation, particles, sound | Node HP, damage validation, yield |
| Predicted ore counter (cosmetic) | Authoritative ore/coin balance |
| UI state, tab navigation | Purchase legality, cost deduction |
| Camera, layer visuals | Layer unlock checks |

The client shows a **predicted** counter for responsiveness, reconciled against the
server every tick. A mismatch snaps to server value — silently on small deltas,
logged to analytics on large ones.

### RemoteEvents / RemoteFunctions
- `RE_Swing` (client→server, **rate-limited to swing-speed + 20% tolerance**)
- `RE_StateUpdate` (server→client, batched at 10Hz, deltas only)
- `RF_Purchase` (client→server→client, returns `{ok, reason}`)
- `RF_Prestige` (server validates threshold independently)
- `RE_Notification` (server→client, toasts)

**Rule:** every remote handler begins with rate-limit → type-check → authority-check.
No exceptions. A single unvalidated remote is a full economy compromise.

### Error handling
- All DataStore calls in `pcall` with exponential backoff (1s, 2s, 4s, 8s, fail)
- Load failure → player enters a **read-only safe session** with a clear UI banner
  and no saving. Never silently hand a player a blank profile; that's how you get
  a wipe report and a lost player.
- Errors tagged by service and shipped to analytics with a severity level

---

## 11. DataStore schema

Session-locked profile store (ProfileService-style pattern). One key per player:
`Player_{UserId}`.

```lua
{
  schemaVersion = 4,

  currencies = {
    coins        = "1.234e18",  -- BigNumber serialized as string
    cores        = "5.6e7",
    shards       = 1420,        -- small, plain number
    ascensionPts = 12,
  },

  progression = {
    currentLayer      = 11,
    highestLayer      = 11,
    delveCount        = 14,
    ascensionCount    = 1,
    lifetimeCoins     = "8.8e21",
    lifetimeCores     = "9.1e8",
    furnaceTier       = 5,
    playtimeSeconds   = 21600,
  },

  upgrades = {
    coin = { pickDamage=142, backpack=88, furnaceSpeed=71, ... },
    core = { startingKit=6, coreMultiplier=14, offlineEff=5, ... },
    ascension = { furnaceSlots=2, offlineCap=1 },
  },

  automation = {
    drills     = { count=34, tier=4 },
    conveyors  = { count=12, tier=3 },
    autoBuy    = { enabled=true, rule="cheapest" },
  },

  quests = {
    daily      = { {id="mine_500_iron", progress=310, target=500, claimed=false} },
    weekly     = { ... },
    lastReset  = 1753800000,
  },

  retention = {
    loginStreak      = 9,
    longestStreak    = 23,
    lastLoginDay     = 20298,   -- days since epoch, UTC
    lastLogoutTime   = 1753812345,
    offlineRateSnap  = "4.2e14",-- coins/sec at logout
  },

  collections = {
    oresDiscovered = {"dirt","stone","copper", ...},
    achievements   = { {id="first_delve", unlockedAt=1753700000} },
    cosmetics      = { owned={"pick_gold","trail_ember"}, equipped={pick="pick_gold"} },
  },

  purchases = {
    gamepasses     = {"auto_sell","vip"},
    productReceipts = {"a1b2c3-...", "d4e5f6-..."},  -- anti-duplication
  },

  meta = {
    createdAt   = 1753000000,
    lastSaveAt  = 1753812345,
    saveCount   = 843,
  },
}
```

### Save / session rules
- **Session locking** — profile claimed on join, released on leave. Prevents the
  classic two-server duplication exploit.
- **Autosave every 120s**, plus on leave, plus on any prestige, plus before any
  Robux purchase is granted.
- **`BindToClose`** with a save-all loop and yield — critical for shutdown saves.
- **Versioned migrations** — `Migrations[3→4]` functions run in sequence on load.
  Never mutate a schema in place without a migration; that is how saves get lost.
- **BigNumbers stored as strings**, never Lua numbers. Values exceed `2^53` by mid
  game and float precision loss becomes visible corruption.

### Anti-duplication
1. Server-authoritative currency, always
2. Session locks on the profile
3. `productReceipts` list checked before granting any dev product
4. Prestige is a single atomic server function — compute, wipe, grant, save
5. Rate-limited remotes with server-side cooldowns
6. Analytics flag on any currency delta exceeding `10× current rate/sec`

---

## 12. UI layout

**Mobile-first.** The majority of Roblox play is on phones; a desktop-first HUD is a
design error.

**Persistent HUD**
- Top-left: Coins, Cores, Shards (abbreviated, tap to see full)
- Top-right: settings, daily reward badge, event timer
- Bottom-left: backpack fill bar (turns red near full)
- Bottom-right: 5 tab buttons — Upgrades, Automation, Quests, Shop, Prestige
- Center-bottom: contextual action button (Mine / Deposit / Sell)
- Prestige tab shows a **live "Delve for N Cores"** badge whenever N > 0

**Upgrades panel**
Single scrolling list, one row per upgrade: icon, name, current level, effect,
cost, buy button. **Buy ×1 / ×10 / ×Max toggle** — non-negotiable, its absence is
the most common complaint in the genre. Affordable upgrades highlighted.

**Prestige panel**
Cores you'd gain, a plain-language explanation of what's lost and kept, a
projection ("your next run reaches layer 11 in ~9 minutes"), and a confirmation with
a hold-to-confirm on the first three Delves only.

**Accessibility:** all number displays respect a "full numbers" toggle, colorblind-
safe rarity palette, and an auto-swing option that removes the click requirement
entirely (this also incidentally removes the incentive to use auto-clickers).

---

## 13. Future update roadmap

| Release | Content | Requires |
|---|---|---|
| **1.0 Launch** | Layers 1–12, Delve, 40 achievements, dailies | — |
| **1.1** (+3 wk) | Ascension, layers 13–16, The Rift | Config + art |
| **1.2** (+6 wk) | Pets/Companions (yield multipliers, collection) | New system |
| **1.3** (+10 wk) | First seasonal event, event currency, event track | Event framework |
| **1.4** (+14 wk) | Trading post (Shards, player-to-player cosmetics) | Trade system |
| **2.0** (+6 mo) | Zone 5 "The Core", third prestige (Convergence) | Config + tuning |
| **2.x** | Guilds, leaderboards, weekly competitive layer-push | Social layer |

**Why this is cheap to keep shipping:** every entry above except Pets, Trading and
Guilds is *config data plus art*. Layers are array entries. Upgrades are table rows.
Prestige layers are a formula and a wipe list. The engineering cost of content is
near-zero after launch, which is what lets a small team sustain a live game.

---

## 14. Monetization

**Gamepasses** (one-time)
- **VIP** (399 R$) — +25% coins, exclusive trail, VIP chat tag, daily bonus ×2
- **Auto-Sell** (199 R$) — unlocks auto-sell immediately instead of at Delve 2
- **×2 Drill Speed** (299 R$)
- **+3 Furnace Slots** (349 R$)
- **Infinite Backpack** (249 R$) — pure QoL, removes the walk
- **Offline 24h** (299 R$)

**Developer products** (repeatable)
- 2× Coins 1h (49 R$) / 4h (129 R$)
- Instant Furnace Fill (25 R$)
- Quest Reroll (15 R$)
- Shard packs (49–499 R$) — cosmetics only

**Cosmetics** — pickaxe skins, trails, mine décor, nameplates. Bought with Shards
(earnable) or Robux. **Every cosmetic is obtainable with Shards eventually.**

### Why this isn't pay-to-win
Nothing purchasable grants power a free player cannot reach. The boosts are
*rate* multipliers on a curve where prestige exponents dominate long-run outcomes —
a paying player arrives sooner, not further. No purchasable currency converts to
Cores or Ascension Points. Leaderboards, if added, must be filtered to
prestige-count rather than raw currency for exactly this reason.

---

## 15. Risks and balancing concerns

| Risk | Severity | Mitigation |
|---|---|---|
| **Prestige exponent mistuned** | Critical | `^0.55` is a config value. Instrument time-between-Delves from day one. This number will be wrong at launch; plan to fix it in week one. |
| **Float precision corruption** | Critical | BigNumber module from day one, stored as strings. Retrofitting this after launch means a save migration nightmare. |
| **Save data loss** | Critical | Session locking, versioned migrations, safe-mode on load failure, `BindToClose`. Never ship a schema change without a tested migration. |
| **Early game too slow** | High | First drill must land under 15 min. If median time-to-first-Delve exceeds 50 min, cut early costs 20%. Day-1 retention lives or dies here. |
| **Mid-game automation void** | High | The gap between "fully automated" and "next prestige" is where incrementals lose players. Quests and achievements exist specifically to fill it. |
| **Exploiters** | High | Server authority, rate-limited remotes, analytics anomaly flags. Assume the swing remote will be attacked on day one. |
| **Mobile performance** | Medium | Hard caps on drills (50) and particles. Batched 10Hz state updates, not per-frame. Test on a low-end Android device, not in Studio. |
| **Content treadmill** | Medium | Config-driven content design; roadmap items are data entries. |
| **Number formatting confusion** | Low | Standard K/M/B/T then `aa/ab/ac`, with a full-number toggle. |

**The honest biggest risk:** this genre is saturated on Roblox and the concept is
intentionally unoriginal. Differentiation must come entirely from *feel* — mining
juice, UI responsiveness, respecting player time — and from update cadence. A
mediocre execution of this design fails. That is a real and accepted trade of the
"no gimmick" constraint.

---

## 16. Development scope

**Team:** 1 programmer, 1 builder/artist, 1 part-time UI designer.

| Phase | Weeks | Work |
|---|---|---|
| Prototype | 2 | Mining loop, one furnace, placeholder UI. **Is swinging fun?** Kill it here if not. |
| Core systems | 4 | ProfileService, economy, BigNumber, upgrades, layers 1–6 |
| Automation | 3 | Drills, conveyors, auto-smelt/sell, offline earnings |
| Prestige | 2 | Delve, Core tree, prestige UI |
| Content | 4 | Layers 7–12, quests, achievements, collections, dailies |
| Polish | 3 | Juice pass, audio, mobile optimization, tutorial |
| Monetization | 1 | Gamepasses, dev products, receipt handling |
| Soft launch | 2 | Closed test, telemetry, curve retuning |
| **Total** | **~21 weeks** | ~5 months to launch |

Ascension and layers 13–16 ship post-launch as 1.1 — deliberately held back so
there's a substantial update ready three weeks after release, when retention
curves need it most.

---

## Summary

**Why it retains long-term.** Retention comes from three nested time horizons
running simultaneously. Minute-to-minute, there's always a purchase under 90 seconds
away. Session-to-session, daily rewards, streaks, AFK earnings and daily quests
give a concrete reason to open the game tomorrow. Month-to-month, prestige layers,
collections and achievements provide goals that survive dozens of sessions. Critically,
the never-resetting currencies — Shards, achievements, cosmetics — mean no session
is ever a total loss, which is what prevents the "I reset and lost everything" churn
that kills weaker incrementals.

**Why it exceeds 5 hours.** The first Delve alone takes ~40 minutes, and the Delve
curve is designed so runs 2–15 each contribute 8–25 minutes of genuinely new
progression rather than repetition — each unlocks a layer, a Core tier, or an
automation system the player has not seen before. That's ~5.5 hours to Ascension,
which is where the endgame *begins*. The 5-hour figure is the floor, not the ceiling,
and it's reached without a single filler grind wall.

**Why it can run for years without redesign.** Content is data. Layers live in an
array; upgrades in a table; quests in a config. Adding zone 5 with four new ores and
a new hazard is a config entry plus art, not an engineering project. The economy
uses sub-linear prestige exponents and no cross-layer currency conversion, so new
tiers can be appended above the existing ones without destabilizing anything below.
A third prestige layer is already specced into the number space. The four-verb
foundation — mine, haul, smelt, sell — means every conceivable future system is a
new instance of a pattern the codebase already handles, which is precisely why a
three-person team can keep shipping to it indefinitely.
