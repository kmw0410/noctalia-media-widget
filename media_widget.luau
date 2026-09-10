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

local function render()
  local showShadow = configBool("show_shadow", true)
  local showProgress = configBool("show_progress", true)
  local hideWhenIdle = configBool("hide_when_idle", false)
  if hideWhenIdle and not state.available then
    desktopWidget.render(ui.box({ width = 1, height = 1, visible = false }))
    return
  end

  local titleProps = {
    text = state.title,
    fontSize = 18,
    fontWeight = "bold",
    color = state.available and "on_surface" or "on_surface_variant",
    maxLines = 1,
    maxWidth = 330,
  }
  local artistProps = {
    text = state.artist,
    fontSize = 14,
    color = "on_surface_variant",
    maxLines = 1,
    maxWidth = 330,
  }

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
  rootProps.fill = "surface/0.92"
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
        state.available = statusResult.exitCode == 0
        state.title = title
        state.artist = artist ~= "" and artist or "Unknown artist / channel"
        state.duration = duration
        state.position = positionResult.exitCode == 0 and (tonumber(trimmed(positionResult.stdout)) or 0) or 0
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

render()
