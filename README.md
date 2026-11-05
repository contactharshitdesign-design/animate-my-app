# animate-my-app

A Claude Code skill that turns an app design into a **native, animated iOS app**, the kind of motion people post and ask "how did you make this?".

Drop in a Figma link or screenshots and ask Claude to animate it. The skill makes Claude:

- build a real SwiftUI app: layout, text, buttons, haptics and safe areas stay native;
- render hero parts (logos, 3D objects, clay characters, paper, chrome, painted backgrounds) in a **three.js** layer, built procedurally rather than from cut-up images;
- move things with **real physics**: damped springs, gravity, squash and stretch that keeps volume, contact shadows, and staging that waits for things to land;
- load every texture and compile every shader **before** the clock starts, so nothing loads mid-animation;
- **test what it builds**: Simulator recordings checked frame by frame, a frame-time probe (target: 0 frames over 25 ms), and an optional self-test on your iPhone;
- ask you about the motion before guessing.

## Install

**Claude Code plugin (recommended)**

```bash
claude plugin marketplace add contactharshitdesign-design/animate-my-app
```

```bash
claude plugin install animate-my-app@animate-my-app
```

Or inside Claude Code: `/plugin marketplace add contactharshitdesign-design/animate-my-app`, then `/plugin install animate-my-app@animate-my-app`.

**npx (copies the skill into `~/.claude/skills`)**

```bash
npx animate-my-app
```

Add `--project` to install it into the current project's `.claude/skills` instead, and `--force` to replace an older copy (it's backed up first).

## Use

Ask Claude Code for any app motion, for example:

- "Animate this onboarding from Figma: <link>"
- "Make the splash logo drop in and squash like clay"
- "The paper should fall onto page 2 with real physics"
- "Turn this seat map into 3D and fly into the seat I tap"

The skill scaffolds an app with `scripts/new_app.sh`, builds it, runs it in the Simulator and reports measured results.

## Requirements

- macOS with Xcode and an iOS Simulator runtime
- Claude Code
- Optional: an Apple developer team ID to run on your own iPhone; the Figma MCP server for Figma links

**Optional companion skills.** If these are installed, the skill loads them; otherwise it uses its own rules:
`motion-design`, `apple-design`, `emil-design-eng`, `micro-interactions`, and Figma's official skills.

## What's inside

```
skills/animate-my-app/
├── SKILL.md            the workflow and the rules
├── references/         stack, motion physics, procedural 3D, testing, research and tools, lessons learned
├── scripts/            new_app.sh scaffold, frame extraction, hitch probe, framed video, SF Symbol export
└── assets/template/    a working SwiftUI + three.js app the scaffold copies
```

## Credits

Built by [@oiharshit](https://x.com/oiharshit). It builds on three.js (MIT), Emil Kowalski's design-engineering teaching and Apple's WWDC talk *Designing Fluid Interfaces*; see [CREDITS.md](CREDITS.md).

## License

[MIT](LICENSE)
