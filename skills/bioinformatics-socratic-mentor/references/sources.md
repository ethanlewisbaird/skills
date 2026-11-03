# Sources and design provenance

Reviewed 2026-11-03 as untrusted reference material. No third-party installation scripts or hooks were executed. All installed skill instructions and Python helpers are newly written; no external project is needed at runtime. MIT notices are retained below conservatively for the adapted instructional techniques.

| Source (reviewed revision) | Reused or adapted | Deliberately rejected |
| --- | --- | --- |
| [rodbv/socratic-skills](https://github.com/rodbv/socratic-skills/tree/dda051c2b4390d19d32b33edc222abbfa39927ac), quiz-me and guide-me SKILL.md; MIT | Actual artifact/diff questions, one-at-a-time follow-ups, implementation review, hints; adapt to scientific invariants and short exercises | User must write all code; refusal to supply solutions; quiz scores or learning as a release gate |
| [ktaletsk/learn-codebase](https://github.com/ktaletsk/learn-codebase/tree/06534bcba81ad14159b372cf4f636abc04d2fe66), SKILL.md, QUESTION-PATTERNS.md, JOURNAL-TEMPLATE.md; MIT | Active recall, prediction, assumption/evidence probes, adaptive scaffolding, journal and relevant spaced retrieval | Repo-local journal, permanent/confident mastery labels, rigid question sequence, latency as ability evidence, fixed success counts implying retention |
| [Learning Output Style](https://claude.com/marketplace/plugins/learning-output-style); [public implementation](https://github.com/anthropics/claude-plugins-official/tree/a7ba5b93db0c7c8d17f3f1d25853adca79598a1a/plugins/learning-output-style); Apache-2.0 | Reviewed README, hook registration and hooks-handlers/session-start.sh. Idea only: agent prepares context and routine implementation while learner contributes a small meaningful function | Global SessionStart hook, instruction injection into unrelated work, fixed insight blocks and mandatory contribution pauses. No source/hook code copied |
| Local official skill-creator and [OpenAI skill documentation](https://learn.chatgpt.com/docs/build-skills) | Progressive disclosure, required frontmatter, UI metadata, official validator, explicit and implicit invocation | No dependencies on a second skill at mentor runtime |

This distributable edition removes the original user-specific salutation, filesystem paths and HPC/report requirements. The original personal installation is separate. See the repository README for agent-specific discovery paths and tested compatibility.

# Third-party MIT notices

## rodbv/socratic-skills

MIT License

Copyright (c) 2026 Rodrigo Vieira

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## ktaletsk/learn-codebase

MIT License

Copyright (c) 2026 Konstantin Taletskiy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Anthropic plugin license reviewed at its plugin-local LICENSE: Apache License 2.0. Attribution above is for ideas; no implementation was incorporated.
