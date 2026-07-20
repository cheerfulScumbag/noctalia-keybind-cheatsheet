# Project Guidance

## Implementation Decisions

- Prefer Noctalia's documented declarative UI and runtime APIs.
- If a requested behavior is unsupported, uncertain, or would require a hacky
  workaround, stop before changing code. Explain the limitation and the
  compatibility or maintenance tradeoffs, present the practical alternatives,
  and ask the user which direction they prefer.
- Do not silently approximate a requested design with unusual encoding,
  undocumented properties, or fragile rendering behavior.
- For unsupported visual effects, offer supported alternatives such as muted
  colors or reduced opacity before proposing a text-encoding workaround.
- Once the user approves a workaround, keep it narrowly scoped and document why
  it is necessary.
