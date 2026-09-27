# Ollama Modelfiles

The local models used by Open WebUI.

| Modelfile | Model |
| --- | --- |
| `Modelfile.qwen-uncensored` | `qwen-uncensored`: abliterated Qwen 3.5 4B, all layers on the GPU. |
| `Modelfile.nico` | `nico`: roleplay persona on top of `qwen-uncensored` |

## Build them

```bash
ollama pull huihui_ai/qwen3.5-abliterated:4B
cd ~/.config/scripts/ollama-modelfiles
ollama create qwen-uncensored -f Modelfile.qwen-uncensored   # first: nico builds on it
ollama create nico -f Modelfile.nico
```

## Use them

Pick them in Open WebUI's model selector (the robot icon in waybar starts it),
or straight from a terminal with `ollama run qwen-uncensored` / `ollama run nico`.

Thinking can't be set in a Modelfile (Ollama rejects `PARAMETER think`); it's
chosen per request, which Open WebUI's Thinking button does
(`/set think` / `/set nothink` inside `ollama run`).

The Hermes-based personas that used to live here (Archie, CyberBard, Der
Lektor, Markdown Guru) were early experiments and were dropped on 2026-09-25;
they are still in git history.
