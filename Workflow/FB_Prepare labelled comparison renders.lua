-- @description Prepare labelled comparison renders and an exact settings manifest
-- @version 0.1.0
-- @author Fat Berry DSP
-- @license MIT
-- @link Source https://github.com/humanmedtechltd-alt/fat-berry-reaper-comparison
-- @about
--   Prepare a separate render project for selected tracks, labelled A01, A02,
--   etc., with a private settings manifest. Works with any plug-ins or none.
--   No rendering, playback, network requests or source-media copying occurs.
--   Selected-track stems exclude master FX; routing remains in the project.

local function json(value)
  local kind = type(value)
  if kind == 'string' then
    return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
      return ({['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'})[c]
        or string.format('\\u%04x', string.byte(c))
    end) .. '"'
  elseif kind == 'number' then
    assert(value == value and math.abs(value) ~= math.huge, 'Nonfinite value')
    return string.format('%.17g', value)
  elseif kind == 'boolean' then return value and 'true' or 'false'
  elseif kind == 'table' then
    local parts = {}
    if getmetatable(value) == 'array' then
      for _, v in ipairs(value) do parts[#parts+1] = json(v) end
      return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}; for key in pairs(value) do keys[#keys+1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts+1] = json(key) .. ':' .. json(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  error('Unsupported manifest value')
end

local arrayMeta = { __metatable = 'array' }
local function array() return setmetatable({}, arrayMeta) end
local function exists(path)
  local file = io.open(path, 'rb'); if file then file:close(); return true end
  return false
end
local function writeNew(path, content)
  assert(not exists(path), 'Output already exists: ' .. path)
  local file = assert(io.open(path, 'wb'))
  assert(file:write(content)); assert(file:close())
end

local function prepare(output)
  local project, projectFile = reaper.EnumProjects(-1, '')
  assert(project, 'Open a REAPER project first')
  assert(reaper.GetPlayState() == 0, 'Stop playback/recording before preparing comparisons')
  local count = reaper.CountSelectedTracks(project)
  assert(count >= 2, 'Select at least two comparison tracks')
  assert(type(output) == 'string' and (output:match('^%a:[/\\]') or output:match('^/')),
    'Choose an absolute output directory')
  output = output:gsub('\\', '/'):gsub('/+$', '')
  assert(not reaper.EnumerateFiles(output, 0) and not reaper.EnumerateSubdirectories(output, 0),
    'Choose a new or empty directory to avoid overwriting work')
  for i = 0, reaper.CountTracks(project)-1 do
    assert(reaper.GetMediaTrackInfo_Value(reaper.GetTrack(project,i), 'I_SOLO') == 0,
      'Clear track solos before preparing independent comparison stems')
  end
  local first, last = reaper.GetSet_LoopTimeRange2(project, false, false, 0, 0, false)
  if last <= first then first = 0; last = reaper.GetProjectLength(project) end
  assert(last > first, 'Project or time selection has no duration')
  local tracks, manifestTracks = {}, array()
  for i = 0, count-1 do
    local track = reaper.GetSelectedTrack(project, i)
    assert(reaper.GetMediaTrackInfo_Value(track, 'B_MUTE') == 0, 'Unmute selected comparison tracks first')
    local _, name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
    local label = string.format('A%02d', i+1)
    tracks[#tracks+1] = {track=track, name=name, label=label}
    local effects = array()
    for fx = 0, reaper.TrackFX_GetCount(track)-1 do
      local _, fxName = reaper.TrackFX_GetFXName(track, fx, '')
      local _, ident = reaper.TrackFX_GetNamedConfigParm(track, fx, 'fx_ident')
      local parameters = array()
      for parameter = 0, reaper.TrackFX_GetNumParams(track, fx)-1 do
        local _, title = reaper.TrackFX_GetParamName(track, fx, parameter, '')
        local _, display = reaper.TrackFX_GetFormattedParamValue(track, fx, parameter, '')
        parameters[#parameters+1] = {index=parameter, name=title, display=display,
          normalized=reaper.TrackFX_GetParamNormalized(track, fx, parameter)}
      end
      effects[#effects+1] = {name=fxName, identity=ident, parameters=parameters,
        enabled=reaper.TrackFX_GetEnabled(track, fx), offline=reaper.TrackFX_GetOffline(track, fx)}
    end
    manifestTracks[#manifestTracks+1] = {label=label, originalName=name,
      guid=reaper.GetTrackGUID(track), effects=effects,
      volume=reaper.GetMediaTrackInfo_Value(track, 'D_VOL'),
      pan=reaper.GetMediaTrackInfo_Value(track, 'D_PAN'),
      expectedFile=label .. '.wav'}
  end
  local numbers = {'RENDER_SETTINGS','RENDER_BOUNDSFLAG','RENDER_STARTPOS','RENDER_ENDPOS',
    'RENDER_SRATE','RENDER_CHANNELS','RENDER_TAILFLAG','RENDER_NORMALIZE','RENDER_ADDTOPROJ'}
  local strings = {'RENDER_FILE','RENDER_PATTERN','RENDER_FORMAT'}
  local savedNumbers, savedStrings = {}, {}
  local dirty = reaper.GetSetProjectInfo(project, 'DIRTY', 0, false)
  for _, key in ipairs(numbers) do savedNumbers[key] = reaper.GetSetProjectInfo(project,key,0,false) end
  for _, key in ipairs(strings) do local _, value = reaper.GetSetProjectInfo_String(project,key,'',false); savedStrings[key] = value end
  local function restore()
    for _, entry in ipairs(tracks) do reaper.GetSetMediaTrackInfo_String(entry.track,'P_NAME',entry.name,true) end
    for key, value in pairs(savedNumbers) do reaper.GetSetProjectInfo(project,key,value,true) end
    for key, value in pairs(savedStrings) do reaper.GetSetProjectInfo_String(project,key,value,true) end
    reaper.GetSetProjectInfo(project,'DIRTY',dirty,true)
  end
  local ok, failure = xpcall(function()
    reaper.RecursiveCreateDirectory(output, 0)
    assert(not exists(output .. '/comparison.rpp') and not exists(output .. '/settings.json'), 'Output files already exist')
    for _, entry in ipairs(tracks) do reaper.GetSetMediaTrackInfo_String(entry.track,'P_NAME',entry.label,true) end
    -- Request stems (bit 1) and exclude the master render (bit 2).
    local values = {RENDER_SETTINGS=3, RENDER_BOUNDSFLAG=0, RENDER_STARTPOS=first,
      RENDER_ENDPOS=last, RENDER_SRATE=48000, RENDER_CHANNELS=2,
      RENDER_TAILFLAG=0, RENDER_NORMALIZE=0, RENDER_ADDTOPROJ=0}
    for key, value in pairs(values) do reaper.GetSetProjectInfo(project,key,value,true) end
    reaper.GetSetProjectInfo_String(project,'RENDER_FILE',output,true)
    reaper.GetSetProjectInfo_String(project,'RENDER_PATTERN','$track',true)
    reaper.GetSetProjectInfo_String(project,'RENDER_FORMAT','ZXZhdyAAAA==',true)
    reaper.Main_SaveProjectEx(project,output .. '/comparison.rpp',0)
    assert(exists(output .. '/comparison.rpp'), 'REAPER did not save the render project')
    local manifest = {schemaVersion=1, scriptVersion='0.1.0', state='prepared-no-audio-rendered',
      sourceProject=projectFile, createdAt=os.date('!%Y-%m-%dT%H:%M:%SZ'),
      render={startSeconds=first,endSeconds=last,sampleRate=48000,channels=2,
        mode='selected-track-stems',format='32-bit float WAV',masterFxIncluded=false,
        loudnessMatched=false}, tracks=manifestTracks,
      privacy='Full project and manifest are private working files. Nothing is uploaded.'}
    writeNew(output .. '/settings.json', json(manifest) .. '\n')
  end, debug.traceback)
  restore()
  assert(ok, failure)
  return output .. '/comparison.rpp'
end

-- Returning the function allows a production launcher to prepare a chosen
-- project on an isolated desktop without showing an input dialog.
if ... == 'library' then return prepare end
local projectPath = reaper.GetProjectPath('')
local defaultPath = projectPath .. '/comparison-' .. os.date('%Y%m%d-%H%M%S')
local accepted, output = reaper.GetUserInputs('Prepare comparison renders',1,'New output directory:',defaultPath)
if accepted then
  local ok, result = pcall(prepare,output)
  reaper.ShowMessageBox(ok and ('Prepared: ' .. result .. '\n\nRender this project separately. Audio has not been rendered or loudness-matched. Master FX are excluded from stems.')
    or tostring(result), 'Comparison preparation', 0)
end
