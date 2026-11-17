#!/usr/bin/env bash
# Builds nekosec's sounds into this folder (ffmpeg, espeak-ng). `neko sound NAME`
# picks a set, `neko sounds` lists them; each set has -notify, -unlock and -startup.
#   chirp  a synthesised meow: a pitch glide with a second harmonic
#   robo   espeak-ng saying "nya", pitched up: the AI catgirl
#   blip   8-bit square-wave blips, like the pixel font
set -euo pipefail
cd "$(dirname "$0")"
enc=(-ac 1 -ar 44100 -c:a libvorbis -q:a 4 -y -loglevel error)

# meow F0 T: rises from F0 by 1.6x and falls back over T seconds
meow() {
  local f0=$1 T=$2
  echo "0.5*(sin(2*PI*($f0*t+$f0*0.6*$T/PI*(1-cos(PI*t/$T))))+0.35*sin(4*PI*($f0*t+$f0*0.6*$T/PI*(1-cos(PI*t/$T)))))*min(1,t/0.02)*pow(sin(PI*min(t,$T)/$T),0.7)"
}
ffmpeg -f lavfi -i "aevalsrc='$(meow 520 0.32)':d=0.34" -af "highpass=f=250,lowpass=f=4200,aecho=0.6:0.3:40:0.25,volume=0.9" "${enc[@]}" chirp-notify.ogg
ffmpeg -f lavfi -i "aevalsrc='$(meow 600 0.22)':d=0.24" -f lavfi -i "aevalsrc='$(meow 700 0.30)':d=0.32" \
  -filter_complex "[0][1]concat=n=2:v=0:a=1,highpass=f=250,lowpass=f=4500,aecho=0.6:0.3:40:0.25" "${enc[@]}" chirp-unlock.ogg
ffmpeg -f lavfi -i "aevalsrc='$(meow 440 0.5)':d=0.52" -af "highpass=f=200,lowpass=f=4000,aecho=0.7:0.4:60:0.3" "${enc[@]}" chirp-startup.ogg

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
espeak-ng -v en+f4 -p 90 -s 150 -w "$tmp/nya.wav" "nyah"
espeak-ng -v en+f4 -p 95 -s 170 -w "$tmp/nyanya.wav" "nyah nyah"
espeak-ng -v en+f4 -p 80 -s 140 -w "$tmp/online.wav" "neko sec online"
for x in nya:notify nyanya:unlock online:startup; do
  ffmpeg -i "$tmp/${x%%:*}.wav" -af "asetrate=22050*1.25,aresample=44100,aecho=0.7:0.5:25:0.3,volume=1.4" "${enc[@]}" "robo-${x#*:}.ogg"
done

sq() { echo "0.25*sgn(sin(2*PI*$1*t))"; }
ffmpeg -f lavfi -i "aevalsrc='$(sq 1320)':d=0.06" -f lavfi -i "aevalsrc='$(sq 1760)':d=0.09" \
  -filter_complex "[0][1]concat=n=2:v=0:a=1,afade=t=out:st=0.12:d=0.03" "${enc[@]}" blip-notify.ogg
ffmpeg -f lavfi -i "aevalsrc='$(sq 880)':d=0.07" -f lavfi -i "aevalsrc='$(sq 1320)':d=0.07" -f lavfi -i "aevalsrc='$(sq 1760)':d=0.12" \
  -filter_complex "[0][1][2]concat=n=3:v=0:a=1,afade=t=out:st=0.22:d=0.04" "${enc[@]}" blip-unlock.ogg
ffmpeg -f lavfi -i "aevalsrc='$(sq 660)':d=0.08" -f lavfi -i "aevalsrc='$(sq 880)':d=0.08" -f lavfi -i "aevalsrc='$(sq 1100)':d=0.08" -f lavfi -i "aevalsrc='$(sq 1320)':d=0.2" \
  -filter_complex "[0][1][2][3]concat=n=4:v=0:a=1,afade=t=out:st=0.38:d=0.06" "${enc[@]}" blip-startup.ogg
ls -la *.ogg | awk '{print $5, $NF}'
