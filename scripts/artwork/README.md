# Orbi plush avatar artwork

`macos/Resources/PlushAvatars/base.png` is the neutral, transparent, 900 × 900 plush planet texture. The planet, diagonal orbit, and upper-right satellite form one image so changing colors keeps their silhouette and occlusion consistent.

`plush-overlays.js` contains the editable Canvas artwork for the eyes, glasses, and accessories. Each PNG in `PlushAvatars/eyes`, `glasses`, and `accessory` is a transparent 900 × 900 layer exported from these drawing functions. Eyes and glasses use `(441, 357, 2.3)` for the center and scale; accessories use `(441, 357, 1)`.

The AppKit renderer in `PlushAvatar.swift` colors the neutral fur while retaining its luminance and alpha, colors accessory layers independently, and composes the selected layers. The bot editor exports the result through the existing encrypted avatar attachment flow. The `orbi-plush-v1-…png` attachment filename carries the part indices and colors; the v1 option arrays keep their existing order when new options are added.

`scripts/app.ts` bundles the PNG directory with both development and release applications.
