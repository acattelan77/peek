# Contributing

Small, focused changes are preferred. For an architectural or product-scope
change, open an issue first so the scope can be agreed.

Humans and agents follow the same process, described in [`AGENTS.md`](AGENTS.md):
where each fact lives, how to claim work, the invariants that must not break,
the checks to run, and how to version and hand off. Build and test details are
in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

In short:

1. Check `docs/ROADMAP.md` and the top-level files in `docs/workstreams/`.
2. Branch from `main` and claim the work with a copy of
   `docs/workstreams/TEMPLATE.md`.
3. Add tests for behavior changes; localize every new string; use design tokens.
4. Run the checks, the unsigned build and the test suite.
5. Bump the version when `docs/VERSIONING.md` requires it and add a
   `CHANGELOG.md` entry.
6. Open a pull request and fill in its template.

Never commit calendar data, screenshots with real events, real names or email
addresses, signing material, API keys, `build/` or `artifacts/`.

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).

Security issues: see [`SECURITY.md`](SECURITY.md).
