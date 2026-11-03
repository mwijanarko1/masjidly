# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# i18n
- Leave inert localization entries in Localizable.xcstrings when removing language support rather than deleting them, to avoid massive catalog diffs. Confidence: 0.60
- Remove settings UI controls entirely when only one option remains (a one-option picker adds no value). Confidence: 0.60
- When iterating on new features, add English-only localization strings first; skip ar/ur translations until the feature stabilizes. Confidence: 0.65

# state-management
- Use Zustand persist migrate with a version bump to coerce legacy stored values when narrowing a persisted field's type. Confidence: 0.60

# communication
- When user-facing copy is involved (What's New, release notes, strings), show the exact literal text verbatim in the reply (per language, as title + description), not just a summary of what changed. Confidence: 0.7
- After code was implemented (especially when delegated to a subagent), expects a plain-language walkthrough of what changed — root cause, fix behavior, tests added, and tradeoffs — rather than just a diff or a one-line "done". Confidence: 0.6
- Asks follow-up "is it doing X every time?" questions about runtime cost/behavior, and wants a precise answer grounded in the actual call sites (which requests fire on resume vs. tab switch vs. cache hit), including the stated tradeoff. Confidence: 0.55

# release
- Shipping a user-facing fix means bumping versions on *both* iOS and Android in the same change, and updating the in-app What's New entry — never one platform in isolation. Confidence: 0.65
- On iOS, bump only `MARKETING_VERSION` and leave `CURRENT_PROJECT_VERSION` (build number) at 1; don't bump the build number as part of a release. Confidence: 0.55
- Keep What's New/release-note copy translated into every supported language (ar/ur/id as well as English) on both platforms, plus paste-ready Play Store release notes per version. Confidence: 0.6
- For bug-fix releases, prefer vague generic release-note descriptions ("Minor bug fixes and improvements.") over naming the specific issue that was fixed in user-facing copy. Confidence: 0.65

# workflow
See [workflow/taste.md](workflow/taste.md)
