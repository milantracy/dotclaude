# Overlay detection

| Signal | Overlay dir |
|---|---|
| `go.mod` module `gvisor.dev/gvisor`, or a remote URL containing `google/gvisor` | `projects/gvisor/` |

If no signal matches, no overlay applies. Use the guidance in the repository:
`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.gemini/styleguide.md`, and the CI
configuration.

To add a project, make `projects/<name>/review.md`, `ship.md`, or both. Then add
a row to the table.
