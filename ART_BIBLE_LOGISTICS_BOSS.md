# LOGISTICS BOSS — Visual Implementation Art Bible

Status: **Canonical visual implementation specification**
Last synchronized: 2026-09-16 JST
Applies only to: **LOGISTICS BOSS**
Related: `GDD_LOGISTICS_BOSS.md`, `GAME_DEV_MASTER_RULES.md`

## 1. Purpose

This document converts the approved completion visual into a production-ready visual implementation target.

The target image is a **North Star**, not a literal pixel-for-pixel runtime requirement. The production goal is to preserve the same player impression while remaining readable, performant, maintainable and feasible on native iOS / Android.

Primary visual promise:

> A premium portrait 3D logistics diorama where the player can read flow, congestion and growth at a glance.

The scene must communicate the core loop visually:

**observe flow → find bottleneck → intervene → watch autonomous logistics react → measure improvement → expand.**

## 2. Visual North Star

### World impression

- premium stylized industrial logistics center
- open-top / cutaway warehouse
- readable three-quarter top-down / elevated camera
- miniature-diorama feel rather than photorealism
- credible logistics structure without simulation-game visual clutter
- active but controlled facility density
- visible Rank growth from small depot to fulfillment center

### Palette roles

- **Dark navy / charcoal:** architecture, floors, background structure, primary HUD surfaces
- **Cyan:** technology, selected state, valid flow, active systems, information emphasis
- **Amber / orange:** safety, operational pressure, warnings, congestion, high-priority activity
- **Warm white:** local work lighting and human-scale activity
- **Green:** positive improvement / valid completion only; do not use as a dominant environment color
- **Red:** exceptional alert / severe congestion only; never as ordinary decoration

### Shape language

- strong rectangular industrial modules
- rounded UI panels, not rounded warehouse geometry everywhere
- equipment silhouettes readable from overview distance
- rails, racks and docks form clear directional lines
- facility expansions must change silhouette, footprint or vertical mass

## 3. Camera and composition

### Mandatory

- portrait-first composition at 390×844 reference viewport
- warehouse remains the visual focal point
- maximum zoom-out shows the facility as a readable whole
- close zoom must still preserve spatial context
- camera angle must make inbound → storage → picking → packing → shipping visually traceable
- major zones must remain distinguishable without opening Management
- no roof / truss / decorative structure may hide the logistics operation

### Preferred composition

At mature Rank 3, the player should be able to identify approximately:

1. Receiving / inbound edge
2. Storage rack mass
3. Picking activity zone
4. Packing / consolidation zone
5. Outbound docks / routing edge
6. Visible annex / expansion structure

The scene does not need permanent floating labels over every zone. Geometry, lighting, flow direction and activity density should do most of the communication.

## 4. Must / Nice / Cut

### MUST — production-critical

These elements define the product and must survive optimization.

- open-top / cutaway logistics center
- clear inbound → storage → picking → packing → outbound spatial flow
- dark navy + cyan + amber art direction
- readable bottleneck state in-world and in HUD
- visible autonomous workers / forklifts / cargo movement
- facility growth visibly changes 3D geometry
- Rank 1, Rank 2 and Rank 3 have clearly different scale impressions
- active facility feels alive even when the player does nothing
- investments with physical meaning have visible physical results
- congestion can be recognized without relying only on text
- premium but restrained HUD
- scene remains readable on actual phone size
- stable performance takes priority over decorative density

### NICE — add when budget allows

- warm local work lights around active stations
- subtle emissive cyan equipment accents
- occasional truck arrival/departure staging
- pallet / parcel density variation by workload
- light environmental decals / lane markings
- restrained VFX for investment completion, rank-up and bottleneck resolution
- small office / control-room visual language
- mild background landscaping / exterior context
- high-level route highlight when routing decisions matter
- selective reflective / metallic material response

### CUT FIRST — remove before harming readability or performance

- large numbers of unique tiny props
- excessive individual parcel variants
- dense wall slogans / decorative text
- roof detail that is invisible at gameplay distance
- many real-time shadow-casting lights
- large worker crowds used only as decoration
- high-frequency particles
- decorative AGV / sorter / ASRS systems without Domain value
- excessive glow / bloom
- unique geometry for every rack or dock
- constant floating labels over every station
- interior details that cannot be read on a phone

## 5. Runtime realism target

Do **not** attempt photorealism.

Target approximately:

- real logistics layout logic
- simplified industrial materials
- exaggerated silhouettes and spacing for mobile readability
- controlled asset repetition
- selective high-quality hero equipment
- readable lighting rather than physically perfect lighting

The player should think "this feels like a real logistics center" without requiring real-world geometric density.

## 6. Environment modularity

Warehouse art should be built from reusable modules.

Recommended module families:

- floor tile / lane tile
- wall / cutaway wall
- dock bay
- rack single / rack block
- receiving station
- picking station
- packing station
- outbound staging block
- office/control module
- annex shell
- routing / dispatch module
- forklift parking / charging marker
- safety rail / bollard / lane marking

Avoid unique one-off geometry where a modular composition can create the same impression.

## 7. Rank visual progression

### Rank 1 — Small Depot

Visual goal: **small, understandable, slightly constrained.**

- compact footprint
- 3 workers visibly matter
- few racks
- limited dock capacity
- one dominant operational floor
- large empty / unused edges are acceptable
- player can visually understand the entire system in seconds

The facility should feel improvable, not already impressive.

### Rank 2 — Warehouse

Visual goal: **the operation has become a system.**

- wider footprint
- clearer zoning
- stronger rack mass
- more simultaneous activity
- selected Zone A / B / C expansions visibly differentiate the facility
- staffing changes should alter where activity accumulates
- workload waves should be visible as changes in density / queue pressure

Rank 2 should be the first stage where the player begins to feel operational complexity.

### Rank 3 — Fulfillment Center

Visual goal: **large, successful, busy, but still readable.**

- visibly larger site footprint
- Receiving Annex changes building silhouette
- routing / outbound area feels more industrialized
- multiple active flow lines can coexist
- storage volume and traffic density increase
- facility still reads as one coherent system at maximum zoom-out

Rank 3 is the closest runtime target to the approved North Star image, but runtime density should remain below concept-art density where necessary.

## 8. Bottleneck visualization

Congestion must be readable through multiple signals.

Preferred signals:

- queue length / parcel accumulation
- reduced motion at blocked stage
- denser activity around constrained station
- amber/orange zone accent
- subtle pulse / warning edge
- short HUD diagnosis

Do not rely on red tint alone.

Avoid turning bottlenecks into giant arcade warning effects. The player should feel like an operations manager diagnosing a real flow problem.

## 9. Workers, forklifts and cargo

### Workers

- stylized low-to-mid detail
- strong silhouette and vest / helmet readability
- do not require facial detail at gameplay distance
- reuse animation sets
- visible task purpose matters more than model uniqueness

### Forklifts

- hero automation object
- readable from medium zoom
- strong amber / industrial silhouette
- movement should communicate actual Domain activity
- no fake decorative loops that contradict simulation state

### Cargo

- parcel / pallet variation may be limited
- density is more important than unique textures
- use pooled / instanced visuals where practical
- cargo accumulation is an operational signal, not merely decoration

## 10. Lighting strategy

Primary target: premium readability at mobile cost.

Prefer:

- baked / precomputed environment lighting where practical
- limited dynamic key lights
- emissive material accents for technology cues
- localized warm station lights
- restrained shadow casters
- strong ambient separation between floor, equipment and cargo

Do not chase the concept image's full cinematic light count in runtime.

If lighting reduces worker / cargo readability, readability wins.

## 11. Material strategy

Use a small controlled material family:

- matte charcoal painted steel
- dark navy architectural panels
- muted concrete floor
- cyan emissive technology strip
- amber safety paint
- warm neutral cardboard / pallet material
- restrained brushed metal for hero equipment

Avoid noisy PBR detail at gameplay distance.

## 12. UI visual hierarchy

The 3D facility is the primary surface. HUD should support diagnosis, not compete with it.

### Persistent HUD

Keep compact:

- Cash
- Rank / progression
- Throughput / logistics performance
- speed controls
- current bottleneck signal

### Diagnostic card

May show:

- current bottleneck
- short reason
- short suggested direction

Do not turn this into an automatic optimal-answer button at high ranks.

### Management

- fixed header / footer
- vertically scrolling body
- dark glass / navy surface
- cyan selected state
- amber warning state
- Before / After information is visually prominent
- investment cards emphasize operational result before decorative copy

Avoid oversized permanent bottom navigation if it consumes too much warehouse viewport. The approved concept image is a visual reference, not a mandate to reserve that much screen space at runtime.

## 13. Motion / VFX

Motion should primarily communicate state changes.

High-value motion:

- parcel movement
- worker task transitions
- forklift movement
- dock arrival/departure
- investment construction / activation
- rank-up transformation
- bottleneck resolved feedback
- Before / After result reveal

Low-value motion to avoid:

- decorative particles everywhere
- constant camera shake
- repeated screen flashes
- UI animation that delays decisions

## 14. Audio / haptic visual relationship

Visual events that deserve stronger audio / haptic reinforcement:

- major investment
- rank promotion
- significant throughput improvement
- contract / routing outcome
- critical bottleneck change

Ordinary parcel movement should not generate spam-level feedback.

## 15. Performance budget philosophy

The hard requirement is not an arbitrary polygon target; it is stable representative gameplay on target devices.

Visual systems must support graceful reduction.

Recommended reduction order:

1. decorative props
2. particle count
3. nonessential shadows
4. distant worker / vehicle visual count
5. material complexity
6. secondary lighting
7. minor animation frequency

Do **not** reduce first:

- bottleneck readability
- major equipment silhouettes
- core cargo flow visibility
- facility expansion visibility
- critical UI legibility

Mature Rank 3 must not sustain sub-30 FPS behavior on target devices.

## 16. Mobile readability rules

At actual phone scale:

- important moving objects must be identifiable without zooming fully in
- interactive targets must not depend on tiny geometry
- world-space text must be used sparingly
- floor arrows / lane lines must be thick enough to survive downscaling
- zone separation should come from geometry, spacing, light and activity before text
- avoid micro-icons in the world
- do not assume concept-art detail remains visible in runtime

## 17. Concept image interpretation rules

The approved visual concept is authoritative for:

- overall mood
- camera family
- palette roles
- premium industrial tone
- density aspiration
- visible logistics zoning
- facility growth impression
- management-game identity

It is **not** authoritative for:

- exact number of workers
- exact number of trucks
- exact rack count
- exact light count
- exact UI card dimensions
- decorative signage
- fictional navigation tabs
- exact investment prices / stats displayed in the concept
- systems not present in the GDD

Gameplay and Domain truth remain governed by the GDD and code.

## 18. Visual quality acceptance

A production screen is acceptable when:

1. the player can identify the dominant logistics flow within several seconds
2. the current congestion is visually plausible
3. the facility rank is visually distinguishable
4. the 3D scene remains the focal point
5. UI is readable without covering the operation
6. investments create visible scene change where specified
7. colors retain semantic meaning
8. the scene feels premium without visual noise
9. representative mature Rank 3 remains performant
10. the result evokes the approved North Star even if detail density is lower

## 19. Anti-patterns

Do not ship:

- generic idle-tycoon button wall
- photoreal warehouse with unreadable gameplay
- roofed warehouse that hides flow
- fake conveyor / vehicle activity unrelated to Domain state
- neon everywhere
- permanently red / orange scene with no semantic contrast
- excessive floating labels
- decorative machinery added only because it looks advanced
- visual growth that exists only in UI numbers
- camera framing where the player cannot understand the whole facility

## 20. Production priority

When trade-offs are required, use this order:

**Flow readability → Interaction clarity → Bottleneck readability → Visible progression → Stable performance → Premium lighting/materials → Decorative density.**

The product should look expensive because the scene is coherent, readable and alive — not because every square meter contains detail.
