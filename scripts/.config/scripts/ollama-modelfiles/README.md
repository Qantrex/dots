# Ollama Modelfiles

Custom personas for the `SUPER+SHIFT+A` launcher (`ollama-launcher.sh`, which
lists whatever `ollama list` reports and opens the chosen one in foot).

| Modelfile | Persona |
| --- | --- |
| `Modelfile.arch-helper` | "Archie" — Arch Linux specialist |
| `Modelfile.ethical-hacking` | "CyberBard" — ethical hacking assistant |
| `Modelfile.lector` | "Der Lektor" — proofreader |
| `Modelfile.mdguru` | "Markdown Guru" — Markdown formatting |
| `Modelfile.nico` | "Nico" — fictional character |
| `Modelfile` | base, no persona |

## Build them

None of these had ever actually been built — as of 2026-09-23 `ollama list`
showed only `llama3.2:latest`, so the launcher had only ever offered that one.

```bash
ollama pull hermes3:8b
cd ~/.config/scripts/ollama-modelfiles
for f in Modelfile.*; do
  ollama create "${f#Modelfile.}" -f "$f"
done
ollama list          # the personas should now appear
```

## Why hermes3

These originally read `FROM ./Hermes-2-Pro-Llama-3-8B-Q4_K_M.gguf` — a 4.6 GB
file sitting in `~/ollama_models`, downloaded 2025-09 and hand-managed.
`hermes3:8b` is the same lineage (NousResearch), current, and pulls straight
from the registry, so there's no multi-gigabyte blob to babysit. The loose
GGUF was removed once these were repointed.

To use a different base — an uncensored variant, say — change the `FROM` line;
`dolphin3`, `llama2-uncensored` and `wizard-vicuna-uncensored` are all in the
registry.

> Keep the `TEMPLATE` block in step with the base model. These use ChatML,
> which suits the Hermes line; a Llama-2-derived base wants a different one.
