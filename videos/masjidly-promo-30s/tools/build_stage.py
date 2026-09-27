#!/usr/bin/env python3
"""Inline tools/stage.js into tools/stage.template.html -> compositions/v2/stage.html.
Sub-compositions must carry their scripts inside <template>, so the JS is kept in its own file
for editing and inlined here. Run from the project root after editing either file."""
import pathlib
tpl = pathlib.Path("tools/stage.template.html").read_text(encoding="utf-8")
js = pathlib.Path("tools/stage.js").read_text(encoding="utf-8")
assert "/*STAGE_JS*/" in tpl
pathlib.Path("compositions/v2/stage.html").write_text(tpl.replace("/*STAGE_JS*/", "\n" + js), encoding="utf-8")
print("stage.html built")
