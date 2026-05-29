---
name: Vela Liquid Glass
colors:
  surface: '#f9f9ff'
  surface-dim: '#d4daeb'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3ff'
  surface-container: '#e8eeff'
  surface-container-high: '#e2e8f9'
  surface-container-highest: '#dde2f3'
  on-surface: '#151c28'
  on-surface-variant: '#424753'
  inverse-surface: '#2a303d'
  inverse-on-surface: '#ecf0ff'
  outline: '#727784'
  outline-variant: '#c2c6d5'
  surface-tint: '#095bbf'
  primary: '#00418f'
  on-primary: '#ffffff'
  primary-container: '#0058bc'
  on-primary-container: '#c3d4ff'
  inverse-primary: '#adc6ff'
  secondary: '#006e28'
  on-secondary: '#ffffff'
  secondary-container: '#6ffb85'
  on-secondary-container: '#00732a'
  tertiary: '#332eb2'
  on-tertiary: '#ffffff'
  tertiary-container: '#4c4aca'
  on-tertiary-container: '#d2d1ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004494'
  secondary-fixed: '#72fe88'
  secondary-fixed-dim: '#53e16f'
  on-secondary-fixed: '#002107'
  on-secondary-fixed-variant: '#00531c'
  tertiary-fixed: '#e2dfff'
  tertiary-fixed-dim: '#c2c1ff'
  on-tertiary-fixed: '#0b006b'
  on-tertiary-fixed-variant: '#3531b4'
  background: '#f9f9ff'
  on-background: '#151c28'
  surface-variant: '#dde2f3'
  confidence-high: '#34C759'
  confidence-medium: '#FFCC00'
  confidence-low: '#FF3B30'
  glass-fill-light: rgba(255, 255, 255, 0.4)
  glass-border-light: rgba(255, 255, 255, 0.5)
  surface-background: '#faf9fe'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.04em
  readiness:
    fontFamily: Manrope
    fontSize: 72px
    fontWeight: '800'
    lineHeight: '1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  title-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Manrope
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-sm:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  label-caps:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  stack-sm: 8px
  gutter: 16px
  stack-md: 16px
  margin-mobile: 20px
  stack-lg: 32px
  margin-desktop: 40px
  nav-offset: 88px
---

## Brand & Style
Vela is a premium health and wellness platform designed for high-performers who value clarity and scientific precision. The brand personality is serene, intelligent, and revitalizing. 

The visual style is **Glassmorphism**, characterized by a multi-layered "Liquid Glass" aesthetic. It uses soft backdrop blurs, vibrant environmental gradients, and ethereal translucent surfaces to create a sense of lightness and depth. The goal is to make complex physiological data feel airy and approachable rather than clinical.

## Colors
The palette is built on a "Functional Vibrant" logic. The **Primary (Cobalt)** and **Tertiary (Indigo)** colors form the core "Liquid" gradient used for high-impact actions and primary data rings. **Secondary (Emerald)** is reserved for positive health metrics and strain indicators.

The background is not a flat color but a quad-radial gradient using highly desaturated versions of the brand colors (HSLA values around 90-95% lightness) to create an environmental "glow" that interacts with the glass components. Status colors (Confidence) follow a traffic-light system but maintain a high-vibrancy "neon" quality to punch through the translucent layers.

## Typography
Manrope is used exclusively to provide a modern, technical, yet balanced feel. The system relies heavily on **tight letter-spacing** for large display styles to evoke a premium, editorial look. 

Uppercase labels with wide tracking (0.06em) are used for metadata and category headers to provide a structural hierarchy against the softer, rounded UI elements. "Readiness" is a specialized display role specifically for hero-level data points, featuring maximum weight and negative tracking.

## Layout & Spacing
The layout uses a **Fluid Safe-Area** model. The primary content is constrained to a 768px max-width container on desktop to ensure readability of health data, while stretching to maintain a 20px side margin on mobile devices.

A vertical "Stacking" rhythm is utilized: 32px (stack-lg) separates major conceptual sections (e.g., Hero from Metrics Grid), while 16px (stack-md) is used for internal card spacing and grid gaps. Horizontal spacing uses a 16px gutter to maintain a tight, integrated feel for the bento-style cards.

## Elevation & Depth
Depth is created through **Backdrop Blur (32px)** and **Specular Highlights** rather than traditional drop shadows. 

1.  **Base Layer:** The radial gradient background.
2.  **Surface Layer:** Semi-transparent white (`rgba(255,255,255, 0.4)`) with a 1px top/left border of higher opacity to simulate a light source hitting the edge of the glass.
3.  **Floating Elements:** Buttons and active navigation tabs use a linear gradient fill with a subtle 20% opacity drop shadow tinted with the primary color (`#0058bc`) to create a "glow" effect rather than a "weight" effect.
4.  **Inner Glows:** Critical hero circles use inset shadows to create a concave glass effect.

## Shapes
The shape language is highly rounded, emphasizing comfort and biological forms. 
- **Cards:** Use a `2xl` (1.5rem) or `3xl` (2rem) radius for a "bento" look.
- **Buttons & Nav:** Always use `full` (pill) rounding to distinguish interactive elements from informational containers.
- **Progress Indicators:** Use thick, rounded strokes (stroke-linecap: round) for all SVG data visualizations to maintain the "liquid" feel.

## Components
### Buttons
Primary buttons ("Liquid Buttons") use a 135-degree gradient from Primary to Tertiary. They feature a semi-transparent white "sheen" on the top half to simulate a physical 3D glass volume.

### Cards
Glass panels are the primary container. Every card must have a 1px border that is lighter on the top/left and darker/more transparent on the bottom/right to reinforce the glass metaphor. Hover states should scale the card by 1.02x.

### Data Rings
Rings consist of a 50% opacity white background track and a gradient foreground track. The primary ring should be filtered with a 4px drop-shadow glow matching its start color.

### Navigation
The Bottom Nav is a floating glass pill. The active state is indicated by a high-contrast pill container that "lifts" the icon and label, while inactive states use low-opacity variants of the surface color.

### Icons
Use Material Symbols with a "Weight 400" and "Optical Size 24". For active states or Coach-related items, use the "FILL 1" variation.