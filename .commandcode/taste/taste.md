# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# i18n
- Leave inert localization entries in Localizable.xcstrings when removing language support rather than deleting them, to avoid massive catalog diffs. Confidence: 0.60
- Remove settings UI controls entirely when only one option remains (a one-option picker adds no value). Confidence: 0.60
- When iterating on new features, add English-only localization strings first; skip ar/ur translations until the feature stabilizes. Confidence: 0.65

# state-management
- Use Zustand persist migrate with a version bump to coerce legacy stored values when narrowing a persisted field's type. Confidence: 0.60
