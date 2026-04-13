# Water Droplet Character Assets

## Required Assets

This directory should contain the water droplet character sprites for the animated cutscene system.

### Base Character

- **droplet_base.png** (512x512)
  - Main water droplet body shape
  - Transparent background
  - Bright blue color (#4DA6FF or similar)
  - Smooth, rounded droplet shape
  - Kid-friendly, approachable design

### Expression Overlays

All expression sprites should be 512x512 with transparent backgrounds, designed to overlay on the base droplet.

#### expressions/happy.png
- Smiling mouth
- Bright, open eyes
- Optional rosy cheeks

#### expressions/sad.png
- Downturned mouth
- Droopy eyes
- Optional tear drop

#### expressions/surprised.png
- Wide open mouth (O shape)
- Large, round eyes
- Raised eyebrows

#### expressions/determined.png
- Straight, focused mouth
- Narrowed, focused eyes
- Slight frown of concentration

#### expressions/worried.png
- Wavy, uncertain mouth
- Wide, nervous eyes
- Furrowed brow

#### expressions/excited.png
- Wide smile
- Sparkling eyes
- Optional star effects

## Placeholder Creation

Until proper assets are created, you can use simple colored circles:
- Base: Blue circle (512x512)
- Expressions: Simple face drawings on transparent backgrounds

## Texture Atlas (Future Optimization)

For production, combine all expressions into a single texture atlas:
- **atlas/droplet_atlas.png** (2048x2048)
- Contains base + all 6 expressions
- Reduces draw calls and memory usage
