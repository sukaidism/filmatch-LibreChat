---
name: Filmatch
description: A quiet café conversation in cream, charcoal, and matcha green.
colors:
  matcha: 'rgb(64 87 49)'
  matcha-hover: 'rgb(48 67 36)'
  pale-matcha: 'rgb(178 200 143)'
  pale-matcha-hover: 'rgb(202 220 175)'
  cream-canvas: 'rgb(249 246 237)'
  cream-sidebar: 'rgb(239 236 225)'
  cream-panel: 'rgb(255 253 247)'
  cream-secondary: 'rgb(239 235 222)'
  cream-active: 'rgb(226 231 213)'
  charcoal: 'rgb(35 43 33)'
  olive-secondary: 'rgb(80 88 75)'
  olive-muted: 'rgb(94 103 83)'
  light-border: 'rgb(202 207 187)'
  light-field-edge: 'rgb(125 135 113)'
  green-canvas: 'rgb(25 30 24)'
  green-sidebar: 'rgb(21 27 21)'
  green-panel: 'rgb(34 41 32)'
  green-secondary: 'rgb(39 47 36)'
  green-active: 'rgb(47 58 42)'
  warm-white: 'rgb(244 241 230)'
  sage-secondary: 'rgb(190 197 180)'
  sage-muted: 'rgb(184 194 173)'
  dark-border: 'rgb(66 77 59)'
  dark-field-edge: 'rgb(123 139 109)'
typography:
  headline:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '1.875rem'
    fontWeight: 500
    lineHeight: 1.375
    letterSpacing: '-0.025em'
  headline-mobile:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '1.5rem'
    fontWeight: 500
    lineHeight: 1.375
    letterSpacing: '-0.025em'
  auth-title:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '1.875rem'
    fontWeight: 600
    lineHeight: 1.2
  wordmark:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '1.5rem'
    fontWeight: 600
    lineHeight: 1.333333
    letterSpacing: '-0.025em'
  body:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '1rem'
    fontWeight: 400
    lineHeight: 1.5
  supporting:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '0.875rem'
    fontWeight: 400
    lineHeight: 1.625
  control:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '0.875rem'
    fontWeight: 500
    lineHeight: 1.428571
  credit:
    fontFamily: 'Inter, ui-sans-serif, system-ui, sans-serif'
    fontSize: '0.75rem'
    fontWeight: 400
    lineHeight: 1.625
rounded:
  control: '0.75rem'
  surface: '1rem'
  large-surface: '1.5rem'
  auth-control: '0.75rem'
  menu: '0.75rem'
  round: '9999px'
spacing:
  1: '0.25rem'
  2: '0.5rem'
  3: '0.75rem'
  3-5: '0.875rem'
  4: '1rem'
  6: '1.5rem'
  8: '2rem'
components:
  button-primary:
    backgroundColor: '{colors.matcha}'
    textColor: '{colors.cream-panel}'
    typography: '{typography.control}'
    rounded: '{rounded.auth-control}'
    padding: '0 1rem'
    height: '3rem'
  button-primary-hover:
    backgroundColor: '{colors.matcha-hover}'
  button-primary-dark:
    backgroundColor: '{colors.pale-matcha}'
    textColor: '{colors.green-canvas}'
  button-primary-dark-hover:
    backgroundColor: '{colors.pale-matcha-hover}'
  question-button:
    textColor: '{colors.charcoal}'
    typography: '{typography.control}'
    rounded: '{rounded.control}'
    padding: '0.75rem 0.875rem'
  question-button-hover:
    backgroundColor: '{colors.cream-active}'
  auth-field:
    textColor: '{colors.charcoal}'
    rounded: '{rounded.auth-control}'
    height: '3rem'
    padding: '0.125rem 0.875rem 0'
  composer:
    backgroundColor: '{colors.cream-panel}'
    textColor: '{colors.charcoal}'
    rounded: '{rounded.large-surface}'
---

# Design System: Filmatch

## Overview

**Creative North Star: "A moment to slow down"**

Filmatch's café identity uses warm cream, deep matcha, and charcoal with an unembellished text wordmark. Generous space around a short welcome makes the existing conversation interface feel calm and approachable. Inter is self-hosted; the café identity does not depend on a separate display face, photography, or illustration.

Dark mode carries the same hierarchy into deep green neutrals with pale matcha actions. Shared LibreChat primitives retain their keyboard, focus, error, and disabled behavior. The fictional café notice and LibreChat attribution remain readable supporting information.

**Key Characteristics:**

- Warm neutral surfaces with green actions.
- Clear Inter hierarchy and restrained text identity.
- Soft control corners and a larger composer silhouette.
- Tonal separation with modest, functional elevation.

Evidence: `../librechat.filmatch.yaml` (only `interface.theme`), `src/components/Filmatch/Brand.tsx`, `src/components/Auth/AuthLayout.tsx`, `src/components/Chat/{Landing,Header,Footer}.tsx`, `src/components/Chat/Input/{ConversationStarters,ChatForm}.tsx`, and shared `../packages/client/src/components` and `../packages/client/src/theme`. Render references live in `../test-results/filmatch/` for new-chat and login, desktop/mobile, light/dark, plus mobile dark conversation. The surface-specific composition remains in `.impeccable/surfaces/filmatch.md`.

## Colors

The frontmatter preserves the configured RGB notation; aliases with identical values are grouped here by their visual role rather than repeated for every semantic property. The sidecar's eight-step OKLCH strips are synthesized color previews, not additional configured palette tokens.

### Primary

- **Matcha / Matcha Hover:** light-mode accent, links, primary actions, and focus roles.
- **Pale Matcha / Pale Matcha Hover:** dark-mode accent, links, and primary actions. Dark primary buttons use Green Canvas ink.

### Neutral

- **Cream Canvas / Green Canvas:** main page backgrounds.
- **Cream Sidebar / Green Sidebar:** history and navigation backgrounds.
- **Cream Panel / Green Panel:** chat, composer, card, dialog, and menu surfaces.
- **Cream Secondary / Green Secondary:** user messages and secondary surfaces.
- **Cream Active / Green Active:** hovered, selected, and pressed surfaces.
- **Charcoal / Warm White:** primary text; **Olive Secondary / Sage Secondary:** supporting text; **Olive Muted / Sage Muted:** tertiary text.
- **Light Border / Dark Border:** subtle separators and surface edges. **Light Field Edge / Dark Field Edge:** configured field and heavy-edge roles; shared controls may consume their separate inherited control-border role.

**The Semantic Surface Rule.** Choose the existing semantic surface or text role in code; let the theme supply its light/dark value. The palette does not replace LibreChat's inherited status, categorical, or high-contrast colors.

## Typography

**Display and Body Font:** self-hosted Inter with the frontmatter fallback stack.

### Hierarchy

- **Headline:** medium welcome, with the smaller mobile role below the small breakpoint; tightly tracked and balanced within a short measure.
- **Auth Title:** semibold sign-in heading.
- **Wordmark:** semibold accent text, used as identity until final logo artwork exists.
- **Body:** ordinary reading text and composer content.
- **Supporting:** café introduction and auth description, with relaxed leading.
- **Control:** shared button labels; short, sentence-case questions wrap when needed.
- **Credit:** subdued attribution and fictional-context notice.

**The Quiet Identity Rule.** Reuse the text wordmark and Inter hierarchy; preserve the clear distinction between identity, welcome, controls, and supporting copy.

## Layout

Use the existing app shell and responsive drawer. The chat header is (3.25rem) tall. The desktop wordmark is hidden below the small breakpoint so the mobile header has room for navigation, assistant selection, and overflow actions.

The welcome has a maximum width of (28rem), supporting copy (24rem). Suggested questions occupy two columns with a (0.75rem) gap, a group width up to (36rem), and at least (3.5rem) button height. Horizontal group padding grows from (1rem) to (1.5rem) at the small breakpoint. The welcome has (5rem) top padding on mobile and (2rem) above the small breakpoint; these belong to the landing composition, not every future screen.

The composer spans the available width on mobile, with rounded upper corners and square bottom corners; from the small breakpoint all corners round. Its normal width caps are (48rem) at medium and (56rem) at extra-large; the existing maximize preference can override them. Auth forms use the existing (370px) shell width and (1.5rem) inner horizontal padding. Theme/contrast controls in the café auth layout are inline above the form, keeping footer credits clear. Allow credits to wrap in normal document flow.

## Elevation & Depth

Tonal surfaces and thin borders provide most separation. The configured ambient surface elevation is recorded in the sidecar. It is not the composer shadow: the shared composer explicitly uses the inherited medium shadow at rest and large shadow on focus. Retain that distinction instead of claiming a flat system or applying one shadow everywhere.

**The Functional Lift Rule.** Keep elevation attached to existing surface and interaction roles; a question button remains an outlined control rather than a raised card.

Motion uses the configured fast and normal durations for shared controls. Composer and floating-label components also have their existing local timings. Preserve their reduced-motion behavior; the café welcome itself is static.

## Shapes

Controls, auth fields, and menus share soft corners; containers step up to the surface and large-surface radii. Circular composer action controls use the round role. Outlined questions use a thin semantic border. Preserve the mobile composer's open-to-the-bottom silhouette instead of enclosing it in a detached card.

## Components

### Buttons

Primary auth actions use the shared default button with auth sizing and soft shape. Their fill switches from Matcha to Pale Matcha across schemes, with inverse text. Hover follows the corresponding hover role. Shared keyboard focus uses a visible (2px) ring and (2px) offset; disabled actions dim and stop accepting pointer interaction.

Suggested questions use the shared outline button, row size, and theme shape. The border is subtle; hover adds the semantic hover fill. Keep long labels wrapping and retain the full button as the hit target.

### Cards / Containers

The composer is the signature container: semantic composer fill, primary ink, light border, large surface shape, and focus-sensitive elevation. General panels reuse shared surface roles and radii; do not infer a new decorative card pattern from the suggestion grid.

### Inputs / Fields

Auth fields use the existing floating-label input, auth field height, and auth radius. The label lifts on focus or when filled. Focus shifts its border and label to accent; shared invalid and disabled treatments remain intact. Use actual labels and the existing password visibility control.

### Navigation

Navigation is quiet secondary text on the sidebar surface. Shared nav controls become primary text on hover/selection with semantic navigation fills. Mobile uses the existing drawer and accessible overflow menu. Café identity reduces visible advanced controls while retaining their established menu entry points.

### Appearance and Credits

The auth scheme and contrast buttons sit together in normal layout flow. Preserve their accessible labels, pressed state for contrast, and announcements. Fictional-context copy and the LibreChat link use supporting ink; credit links retain underline and visible keyboard focus.

## Do's and Don'ts

### Do:

- **Do** compose shared LibreChat primitives and semantic theme roles.
- **Do** retain light/dark hierarchy, high-contrast controls, and visible keyboard focus.
- **Do** let question labels and credits wrap at mobile widths.
- **Do** keep fictional-context information and LibreChat attribution discoverable.

### Don't:

- **Don't** turn every suggestion into a raised card.
- **Don't** hard-code light-mode colors into a component that must follow the theme.
- **Don't** overlay appearance controls on footer text.
- **Don't** invent logo artwork or introduce a new display font without an approved identity change.

Not canonized: the earlier mobile login theme-control/credits overlap is a corrected layout defect, not a reusable placement rule. The finish review verified refreshed login captures in both schemes and viewport sizes. No new shipping raster assets were introduced.
