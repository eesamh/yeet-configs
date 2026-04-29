---
name: ui-audit
description: Pre-implementation checklist for UI components. Run before writing any styled component from a Figma spec to surface tokens, icons, and patterns upfront instead of in review.
---

## Purpose

This skill front-loads token and pattern discovery before writing UI code. The goal is to answer the following questions once, up front, so the implementation doesn't require corrective round-trips.

Run this before writing any new component or making significant visual changes to an existing one.

---

## Steps

### 1. Read the design system guide

Check whether the project has a design system reference file (e.g. `.claude/figma-design-system.md` or equivalent). If it exists, read it in full before proceeding. Pay attention to:

- Semantic color role tokens (border colors, background, text secondary, etc.)
- Typography scale — note any disabled/overridden variants
- Spacing and border-radius conventions
- Icon selection priority (custom wrappers vs. icon library)
- Any project-specific overrides to MUI/UI framework defaults

### 2. Map every Figma value to a theme token

For each color, spacing, shadow, and border-radius value in the design:

- **Colors** → map to semantic theme tokens first (e.g. `theme.palette.border.secondary`), then raw scales. Never hardcode hex.
- **Spacing/border-radius** → convert px → `theme.spacing(n)` (n = px / 8 for MUI's 8px base). Round to nearest 0.5.
- **Shadows** → grep for an existing multi-layer shadow literal in the codebase before writing one from scratch. Do not use `theme.shadows[n]` for Figma-designed card surfaces — MUI elevation shadows rarely match custom designs.
- **Typography** → confirm variant + weight against the project's type scale. Note any variants the project has disabled (e.g. `h6`, `subtitle2` in some MUI setups).

### 3. Check for existing icons

For every icon in the design:

1. Search the project's custom icon directory (typically `src/components/icons/` or similar) for an existing wrapper
2. Fall back to the UI library's icon package (e.g. `@mui/icons-material`) only if no wrapper exists
3. If neither has it, create a new wrapper following the project's icon pattern

Document which icons you found in each location before writing any import.

### 4. Check for existing components

Search `src/components/` (or the project's component library) for anything that matches the design's patterns — pills, avatars, reading-time displays, CTA buttons, tag chips, etc. Reuse — don't reinvent.

### 5. Identify layout context

Note whether the component will live inside a:

- **Column-direction flex/Stack container** → verify how the project handles full-width buttons (may need explicit `width: '100%'` in addition to `fullWidth` prop)
- **Full-bleed background section** → check how the project achieves full-width backgrounds with constrained content (often nested containers)
- **Page with a fixed overlay element** (bottom nav, floating CTAs) → check whether the project has a padding token for safe-area clearance

### 6. Report findings

Before writing code, output a short summary:

```
Design system guide: [found at X / not found]

Token map:
  - [figma element]: [theme token]
  - [figma element]: [theme token]
  - Shadow: [existing literal found at X / theme.shadows[n] / custom]

Icons:
  - [icon name]: [found at path / @mui/icons-material / needs wrapper]

Existing components to reuse:
  - [list or "none found"]

Layout notes:
  - [flex column / full-bleed / fixed overlay / other]
```

Only then begin the implementation.
