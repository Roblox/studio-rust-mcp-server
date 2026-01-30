## Description

<!-- Briefly describe what this PR does -->

## Rationale

<!-- Explain why this change is needed. What problem does it solve? What value does it add? -->

## Testing Instructions

<!-- Provide clear steps to test this change -->

<!-- If this fixes a bug, include steps to reproduce the original issue -->

---

## Contribution Guidelines

Please ensure your PR follows these guidelines:

### Keep PRs Focused
- **Single feature per PR** - Each PR should address one specific feature, fix, or improvement
- Keep changes brief and reviewable

### For New Tools

When adding a new MCP tool, ensure it meets **all** of the following criteria:

1. **Roblox/Roblox Studio Specific** - The tool must provide functionality specific to Roblox or Roblox Studio. Generic tools (e.g., screenshotting, file operations) can be provided by many existing MCP servers and don't belong here.

2. **More Efficient Than Running Code** - The tool must be more efficient than simply running Luau code in Studio:
   - Do **not** add tools that wrap 1-2 lines of Luau code
   - Tools are announced with every request and consume context window
   - If you frequently reuse code snippets, add them to an AI instruction file instead

### Checklist

- [ ] PR addresses a single feature/fix
- [ ] Rationale for the change is clearly explained above
- [ ] Testing instructions are provided
- [ ] (If fixing a bug) Steps to reproduce the original issue are included
- [ ] (If adding a tool) Tool is Roblox/Roblox Studio specific
- [ ] (If adding a tool) Tool provides significant value over running inline Luau code
