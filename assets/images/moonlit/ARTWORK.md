# Moonlit garden artwork

Original art generated with the built-in OpenAI image generator on 2026-10-18,
using the approved MON PINBALL moonlit garden mockup from this conversation.
No game art from Touhou or other games was imported.

- `garden.png`: opaque 959 x 1640 static dark garden backplate; no obstacles.
- `tsukibina-atlas.png`: transparent 1536 x 1024 atlas, six 512 x 512 cells.
  Top row: central head/body/inner dress; left butterfly wing; right wing.
  Bottom row: left arm/sleeve; right arm/sleeve; outer trailing hem.

The renderer draws each cell independently with shoulder/wing/waist anchors.
Body/chest position is the same board coordinate used by the weak-point sensor.
The atlas is not a completed animation; breathing, flight lag, attack poses and
hit recoil are implemented in code.

Generation brief: create isolated rig parts of the original purple/gold hina
doll with translucent cyan/lilac butterfly wings, delicate embroidered sleeves,
and a separate outer skirt, on a real alpha background in a 3 x 2 grid.
Backplate brief: top-down midnight-indigo pond garden, wisteria/lanterns confined
to outer margins, quiet center, no text/UI/characters/physical pinball objects.
