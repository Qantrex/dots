#!/bin/bash

# Define absolute paths to our dependencies at the top
OLLAMA_CMD="/usr/bin/ollama"
WOFI_CMD="/usr/bin/wofi"
FOOT_CMD="/usr/bin/foot"


# 1. Get the list of locally available models
models=$($OLLAMA_CMD list | tail -n +2 | awk '{print $1}')

# 2. Check if any models were found.
if [ -z "$models" ]; then
    $WOFI_CMD --dmenu --prompt="Error" <<< "No Ollama models found."
    exit 1
fi

# 3. Use wofi to present the list of models
selected_model=$(echo "$models" | $WOFI_CMD --dmenu --prompt=" Ollama: Select a model")

# 4. Check if the user actually made a choice
if [ -n "$selected_model" ]; then
    # 5. Launch a new foot terminal running the selected model.
    echo "Launching '$selected_model'..."
    $FOOT_CMD --title="Ollama - $selected_model" $OLLAMA_CMD run "$selected_model"
else
    echo "No model selected. Exiting."
fi
