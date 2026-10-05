# Orbi plush avatar artwork

`macos/Resources/PlushAvatars/base.png` is the neutral, transparent, 900 × 900 plush planet texture. The planet, diagonal orbit, and upper-right satellite form one image so changing colors keeps their silhouette and occlusion consistent.

`plush-overlays.js` contains the editable Canvas artwork for the eyes, glasses, and accessories. Each PNG in `PlushAvatars/eyes`, `glasses`, and `accessory` is a transparent 900 × 900 layer exported from these drawing functions. Eyes and glasses use `(441, 357, 2.3)` for the center and scale; accessories use `(441, 357, 1)`.

`PlushAvatarShape.swift` defines the eleven body outlines shared by the native color silhouettes and the artwork generator. The circle uses `base.png` directly and keeps its existing pixels. `PlushAvatars/shapes/` contains the ten other neutral bodies: each reshapes clean source fur, shades the new volume, and adds a complete plush orbit in back and front with the original upper-right satellite. A complete orbit makes the portions exposed by smaller or indented bodies continuous. The generator uses fixed sampling and edge fibers, so its output is deterministic. Generate the PNGs from the repository root:

```sh
swiftc -O macos/Sources/Lorca/Design/PlushAvatarShape.swift scripts/artwork/generate-plush-shapes.swift -o /tmp/orbi-plush-shapes
/tmp/orbi-plush-shapes
```

The AppKit renderer in `PlushAvatar.swift` colors the neutral fur while retaining its luminance and alpha, colors accessory layers independently, and composes the selected layers. It loads cached PNGs when shapes change; pixel deformation runs in the offline generator. The eye and glasses alignment stays fixed, while hats and bowties follow the selected body's crown and hem. The bot editor exports the result through the existing encrypted avatar attachment flow. The `orbi-plush-v2-…png` attachment filename carries the shape ID, part indices, and colors; v1 attachments reopen as circles. The part arrays keep their existing order when new options are added.

`scripts/app.ts` bundles the PNG directory with both development and release applications.
