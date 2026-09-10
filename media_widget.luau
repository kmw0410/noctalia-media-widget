--!nonstrict

-- playerctl is an MPRIS client.  It supplies music metadata and, for browsers
-- that expose MPRIS (for example via a browser integration), the video title
-- and channel name in the same artist field.

local state = {
  available = false,
  title = "No media playing",
  artist = "Start a compatible player to begin",
  status = "Stopped",
  position = 0,
  duration = 0,
  queryPending = false,
  playerctlAvailable = nil,
}

local function trimmed(value)
  if value == nil then
    return ""
  end
  return noctalia.string.trim(value)
end

local function splitMetadata(output)
  local fields = string.split(trimmed(output), "\t")
  local title = trimmed(fields[1])
  local artist = trimmed(fields[2])
  local durationMicros = tonumber(trimmed(fields[3])) or 0

  return title, artist, math.max(0, durationMicros / 1000000)
end

local function configBool(key, default)
  local value = noctalia.getConfig(key)
  if value == nil then
    return default
  end
  return value == true
end

local function configNumber(key, default)
  local value = tonumber(noctalia.getConfig(key))
  return value or default
end

local function configFontFamily()
  local value = noctalia.getConfig("font_family")
  if type(value) ~= "string" then
    return ""
  end
  return trimmed(value)
end

local function compactLayout()
  return noctalia.getConfig("layout_type") == "type_2"
end

local function render()
  local showShadow = configBool("show_shadow", true)
  local showProgress = configBool("show_progress", true)
  local hideWhenIdle = configBool("hide_when_idle", false)
  local isCompact = compactLayout()
  local fontFamily = configFontFamily()
  desktopWidget.setNeedsFrameTick(not isCompact and showProgress and state.available and state.status == "Playing" and state.duration > 0)
  if hideWhenIdle and not state.available then
    desktopWidget.render(ui.box({ width = 1, height = 1, visible = false }))
    return
  end

  local titleProps = {
    text = state.title,
    fontSize = configNumber("title_font_size", 18),
    fontWeight = "bold",
    color = state.available and "on_surface" or "on_surface_variant",
    maxLines = 1,
    maxWidth = isCompact and 180 or 330,
  }
  local artistProps = {
    text = state.artist,
    fontSize = configNumber("artist_font_size", 14),
    color = "on_surface_variant",
    maxLines = 1,
    maxWidth = isCompact and 180 or 330,
  }
  if fontFamily ~= "" then
    titleProps.fontFamily = fontFamily
    artistProps.fontFamily = fontFamily
  end

  if isCompact then
    -- Type 2 keeps the metadata and transport controls in a single compact row.
    local controls = ui.row({ gap = 8, align = "center", justify = "end" }, {
      ui.button({ glyph = "player-skip-back", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "previous" }),
      ui.button({ glyph = state.status == "Playing" and "player-pause" or "player-play", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "playPause" }),
      ui.button({ glyph = "player-skip-forward", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "next" }),
    })
    desktopWidget.render(ui.row({
      gap = 12,
      padding = 14,
      radius = 14,
      border = showShadow,
      borderWidth = showShadow and 1 or 0,
      width = 330,
      align = "center",
      justify = "space_between",
    }, {
      ui.column({ gap = 2, width = 180 }, {
        ui.label(titleProps),
        ui.label(artistProps),
      }),
      controls,
    }))
    return
  end

  local content = {
    ui.label(titleProps),
    ui.label(artistProps),
  }

  if showProgress then
    local progress = 0
    if state.duration > 0 then
      progress = math.min(1, math.max(0, state.position / state.duration))
    end
    table.insert(content, ui.progress({
      progress = progress,
      fill = "primary",
      track = "surface_variant",
      radius = 3,
      height = 5,
      width = 330,
    }))
  end

  table.insert(content, ui.row({ gap = 8, align = "center", justify = "end", width = 330 }, {
    ui.button({ glyph = "player-skip-back", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "previous" }),
    ui.button({ glyph = state.status == "Playing" and "player-pause" or "player-play", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "playPause" }),
    ui.button({ glyph = "player-skip-forward", variant = "ghost", controlSize = "sm", enabled = state.available, onClick = "next" }),
  }))

  -- Declarative desktop widgets do not yet expose a true box-shadow property.
  -- The optional border gives the card a subtle elevated edge while retaining
  -- only documented ui.* properties.
  local rootProps = {
    gap = 8,
    padding = 14,
    radius = 14,
    border = showShadow,
    borderWidth = showShadow and 1 or 0,
  }
  desktopWidget.render(ui.column(rootProps, content))
end

local function setUnavailable(message)
  state.available = false
  state.title = message or "No media playing"
  state.artist = state.playerctlAvailable == false and "playerctl is required" or "Start a compatible player to begin"
  state.status = "Stopped"
  state.position = 0
  state.duration = 0
  render()
end

local function refresh()
  if state.queryPending then
    return
  end

  if state.playerctlAvailable == nil then
    state.playerctlAvailable = noctalia.commandExists("playerctl")
  end
  if not state.playerctlAvailable then
    setUnavailable("Media controls unavailable")
    return
  end

  state.queryPending = true
  noctalia.runAsync({ "playerctl", "metadata", "--format", "{{title}}\t{{artist}}\t{{mpris:length}}" }, function(metadataResult)
    if metadataResult.exitCode ~= 0 then
      state.queryPending = false
      setUnavailable()
      return
    end

    local title, artist, duration = splitMetadata(metadataResult.stdout)
    if title == "" then
      state.queryPending = false
      setUnavailable()
      return
    end

    noctalia.runAsync({ "playerctl", "position" }, function(positionResult)
      noctalia.runAsync({ "playerctl", "status" }, function(statusResult)
        state.queryPending = false
        local trackChanged = title ~= state.title
        local reportedPosition = positionResult.exitCode == 0 and tonumber(trimmed(positionResult.stdout)) or nil
        state.available = statusResult.exitCode == 0
        state.title = title
        state.artist = artist ~= "" and artist or "Unknown artist / channel"
        -- MPRIS position/length can be temporarily unavailable while a player
        -- changes state. Keep the last good values so the progress fill does
        -- not jump back to zero or disappear between successful polls.
        if duration > 0 or trackChanged then
          state.duration = duration
        end
        if reportedPosition ~= nil then
          -- The player clock and frame tick arrive on different schedules.
          -- Ignore tiny corrections so the bar never jitters backward; a large
          -- delta is treated as an intentional seek and applied immediately.
          local drift = reportedPosition - state.position
          if trackChanged or math.abs(drift) >= 1.5 then
            state.position = math.max(0, reportedPosition)
          end
        elseif trackChanged then
          state.position = 0
        end
        state.status = statusResult.exitCode == 0 and trimmed(statusResult.stdout) or "Stopped"
        render()
      end)
    end)
  end)
end

local function control(command)
  if not state.available or not state.playerctlAvailable then
    return
  end
  noctalia.runAsync({ "playerctl", command }, function(_)
    refresh()
  end)
end

function previous()
  control("previous")
end

function playPause()
  control("play-pause")
end

function next()
  control("next")
end

function update()
  desktopWidget.setWantsSecondTicks(true)
  refresh()
end

function onFrameTick(deltaMs)
  if compactLayout() or not configBool("show_progress", true) or state.status ~= "Playing" or state.duration <= 0 then
    return
  end

  state.position = math.min(state.duration, math.max(0, state.position + (deltaMs / 1000)))
  render()
end

desktopWidget.setWantsSecondTicks(true)
render()
