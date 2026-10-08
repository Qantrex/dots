#!/usr/bin/env bash
# Local AI (Open WebUI) behind the waybar icon.
#
# Only Ollama runs all the time: 36 MB idle, and the GPU stays asleep until a
# model loads. Open WebUI and SearXNG (its web search) are started and stopped
# here. ComfyUI (images) is not: comfyui-proxy.socket starts it on the first
# image request and it stops after 10 idle minutes. Images go to ~/Pictures/AI.
# Image Studio (~/ai/image-studio, a one-page image generator) works the same
# way through image-studio-proxy.socket: opening it starts it, and it stops 10
# minutes after its last tab closes. It renders on the same ComfyUI with the same
# prompt planner as Open WebUI, but doesn't need Open WebUI running.
#
# Usage:
#   ai-webui.sh toggle     off: start, then open in Firefox; on: stop   (click)
#   ai-webui.sh open       open Open WebUI in Firefox                    (right-click)
#   ai-webui.sh images     open Image Studio in Firefox                  (middle-click)
#   ai-webui.sh status     print waybar JSON
#   ai-webui.sh autostop   stop after IDLE_MINUTES unused (ai-autostop.timer)

set -uo pipefail

readonly URL=http://127.0.0.1:8080
readonly STUDIO_URL=http://127.0.0.1:7801
readonly OLLAMA=http://127.0.0.1:11434
readonly CONTAINERS=(searxng open-webui)
readonly IDLE_MINUTES=45
readonly WAYBAR_SIGNAL=9
readonly STATE=${XDG_CACHE_HOME:-$HOME/.cache}/ai-webui
readonly ACTIVITY=$STATE/last-activity
readonly STARTING=$STATE/starting

readonly ICON=$'\U000f06a9'        # nf-md-robot
readonly IMAGE_ICON=$'\U000f02e9'  # nf-md-image

webui_up()      { curl -sf -m 1 -o /dev/null "$URL/health"; }
# Never probe ComfyUI's port here: any connection to it starts ComfyUI.
comfy_running() { systemctl --user is-active -q comfyui.service; }
# Same for Image Studio's port.
studio_running() { systemctl --user is-active -q image-studio.service; }
loaded_model()  { curl -sf -m 1 "$OLLAMA/api/ps" | jq -r '.models[0].name // empty' 2>/dev/null; }
starting()      { [[ -f $STARTING ]] && kill -0 "$(<"$STARTING")" 2>/dev/null; }

refresh_waybar() { pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null || true; }

notify() {
    notify-send -a "AI" -u "${3:-normal}" \
        -h "string:x-canonical-private-synchronous:ai" \
        "$ICON  $1" "${2:-}" 2>/dev/null || true
}

open_ui() {
    firefox --new-tab "${1:-$URL}" >/dev/null 2>&1
    # Firefox opens the tab but doesn't take focus.
    hyprctl dispatch 'hl.dsp.focus({ window = "class:firefox" })' >/dev/null
}

open_images() {
    if ! studio_running; then
        # The first connection starts it (well under a second); wait for it so
        # Firefox doesn't hit a blank page.
        curl -sf -m 30 -o /dev/null "$STUDIO_URL/" || {
            notify "Image Studio failed to start" "journalctl --user -u image-studio" critical
            return 1
        }
    fi
    refresh_waybar
    open_ui "$STUDIO_URL"
}

fail() {
    rm -f "$STARTING"
    refresh_waybar
    notify "AI failed to start" "$1" critical
    exit 1
}

start() {
    mkdir -p "$STATE"
    echo $$ > "$STARTING"
    refresh_waybar

    local hint="Opens in Firefox when ready."
    [[ -d /sys/module/nvidia ]] || hint="GPU is off (gpumode hybrid, then reboot). $hint"
    [[ $(cat /sys/class/power_supply/A*/online 2>/dev/null) == 1 ]] || hint="On battery: slow. $hint"
    notify "Starting AI…" "$hint"

    local t0=$SECONDS
    docker start "${CONTAINERS[@]}" >/dev/null 2>&1 || fail "docker start failed (docker logs open-webui)"
    until webui_up; do
        (( SECONDS - t0 > 300 )) && fail "Open WebUI did not answer within 5 minutes"
        sleep 1
    done

    rm -f "$STARTING"
    touch "$ACTIVITY"
    systemctl --user start ai-autostop.timer
    refresh_waybar
    notify "AI ready" "Started in $(( SECONDS - t0 )) s."
    open_ui
}

stop() {
    local model
    systemctl --user stop ai-autostop.timer
    docker stop -t 10 "${CONTAINERS[@]}" >/dev/null 2>&1
    systemctl --user stop image-studio-proxy.service image-studio.service comfyui-proxy.service comfyui.service 2>/dev/null
    model=$(loaded_model)
    [[ -n $model ]] && curl -sf -m 30 -o /dev/null "$OLLAMA/api/generate" \
        -d "{\"model\":\"$model\",\"keep_alive\":0}"
    refresh_waybar
    notify "AI stopped" "${1:-Open WebUI, SearXNG and Image Studio are off.}"
}

toggle() {
    if starting; then
        return
    elif webui_up; then
        stop
    else
        start
    fi
}

autostop() {
    if ! webui_up; then
        systemctl --user stop ai-autostop.timer
        return
    fi
    # In use: a model is loaded, an image is rendering, or Open WebUI is the
    # tab in the focused window.
    if [[ -n $(loaded_model) ]] || comfy_running ||
       hyprctl activewindow -j | jq -e '.title | test("Open WebUI")' >/dev/null 2>&1; then
        touch "$ACTIVITY"
        return
    fi
    [[ -f $ACTIVITY ]] || { mkdir -p "$STATE"; touch "$ACTIVITY"; return; }
    if (( $(date +%s) - $(stat -c %Y "$ACTIVITY") > IDLE_MINUTES * 60 )); then
        stop "Unused for $IDLE_MINUTES minutes."
    fi
}

status_json() {
    local state text model comfy studio tooltip
    model=$(loaded_model)
    comfy=0; comfy_running && comfy=1
    studio=0; studio_running && studio=1

    if starting; then state=starting
    elif webui_up; then state=on
    else state=off
    fi

    text=$ICON
    [[ -n $model ]] && text+=" ${model%%:*}" && text=${text/huihui_ai\//}
    (( comfy || studio )) && text+=" $IMAGE_ICON"

    case $state in
        off)      tooltip="AI: off\n\nClick: start and open in Firefox" ;;
        starting) tooltip="AI: starting…" ;;
        on)       tooltip="AI: on\nModel: ${model:-none loaded}\nImages: $( ((comfy)) && echo 'ComfyUI loaded' || echo 'ComfyUI asleep, wakes on first image')\nStops after $IDLE_MINUTES min unused\n\nClick: stop   Right-click: open in Firefox" ;;
    esac
    tooltip+="\nImage Studio: $( ((studio)) && echo 'open (stops 10 min after its tab closes)' || echo off)\nMiddle-click: open Image Studio"
    [[ -d /sys/module/nvidia ]] || tooltip+="\n⚠ GPU is off (gpumode hybrid)"

    printf '{"text":"%s","class":["%s"%s],"tooltip":"%s"}\n' \
        "$text" "$state" "$( [[ -n $model || $comfy == 1 || $studio == 1 ]] && printf ',"busy"')" "$tooltip"
}

case "${1:-status}" in
    toggle)   toggle ;;
    open)     if webui_up; then open_ui; else start; fi ;;
    images)   open_images ;;
    status)   status_json ;;
    autostop) autostop ;;
    *)
        echo "usage: ${0##*/} {toggle|open|images|status|autostop}" >&2
        exit 2
        ;;
esac
