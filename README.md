# Labelled comparison renders for REAPER

A free, open-source ReaScript from Fat Berry DSP. Prepare A01, A02 and further
selected-track comparison renders with a private, exact settings manifest.
Use any plug-ins, stock effects, or no effects. No Fat Berry product is required.

## Use

1. Download `Workflow/FB_Prepare labelled comparison renders.lua`.
2. In REAPER, open Actions, choose New action â†’ Load ReaScript, and select it.
3. Stop playback. Select at least two unmuted comparison tracks and clear solos.
4. Set a time selection, or use the complete project duration.
5. Run the action and choose a new or empty output directory.
6. Open the resulting `comparison.rpp` separately and render its prepared stems.

The action prepares a render project; it does not start playback or render audio.
It restores the original project's track names and render settings. The saved
render project references your existing media; it does not copy or upload it.

## What is included

- `comparison.rpp`: the full routing graph, selected tracks labelled A01, A02,
  etc., and selected-track stem render settings.
- `settings.json`: label-to-track mapping, FX names/identities, host parameter
  values, enabled/offline states, track volume/pan, and render bounds.
- Rendering the prepared project produces stereo, 48 kHz, 32-bit float WAVs.

These are track-stem comparisons: master FX are excluded. Routing and source
availability affect the result. Outputs are not automatically loudness-matched
or a scientific blind test. Keep the identity mapping private when asking
someone to judge unlabelled audio. Listen to and check the actual renders.

The project and manifest can contain private paths, track names and settings.
Nothing is sent over a network. Do not publish these working files without
checking their contents and your rights to the source material.

## Optional Fat Berry example

For a tape-character comparison, duplicate your own drum excerpt onto two
tracks. Leave one untreated and put [Ape Tape](https://fatberrydsp.com/plugins/ape-tape)
on the other. Choose the sound setting yourself, then prepare the comparison.
Use output gain to make your listening comparison fair; the script does not
choose a winner. This is our product, and no purchase is needed to use the script.

## ReaPack

In ReaPack, import this repository URL:

https://raw.githubusercontent.com/humanmedtechltd-alt/fat-berry-reaper-comparison/main/index.xml

The repository's `index.xml` provides this package for import through ReaPack.
Availability in ReaTeam or other community repositories is separate; no community
acceptance or endorsement is claimed.

## Development and licence

MIT licensed. AI tools assisted development and documentation. Native REAPER
operation, generated assets and release observations are recorded separately
from listening decisions or marketing claims.

## Release observation

Version 0.1.0 was operated in native REAPER on Windows using two tracks with no
plug-ins loaded. It produced separate 48 kHz stereo float WAVs and restored the
source track names. Every output sample matched the corresponding input.
REAPER rounded the 7.333333-second requested range to 7.333 seconds: 16 silent
end frames were omitted in this example. Check your own actual render bounds.
Other hosts/platforms, complex routing and plug-in combinations are not covered
by this operation. No listening preference or performance claim is made.
