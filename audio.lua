local Audio = {}

Audio.enabled = true
Audio.volume = 0.3
Audio.sounds = {}

-------------------------------------------------------------------------------
-- TONE GENERATION
-------------------------------------------------------------------------------
local function generateTone(freq, duration, volume, waveform, fadeOut)
    local sampleRate = 22050
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        -- Envelope
        local attack = math.min(1, t / 0.005)
        local release = fadeOut and math.min(1, (duration - t) / (duration * 0.3)) or math.min(1, (duration - t) / 0.02)
        local envelope = attack * release

        local sample = 0
        if waveform == "sine" then
            sample = math.sin(2 * math.pi * freq * t)
        elseif waveform == "square" then
            sample = math.sin(2 * math.pi * freq * t) > 0 and 1 or -1
            sample = sample * 0.5  -- softer squares
        elseif waveform == "triangle" then
            local phase = (freq * t) % 1
            sample = 4 * math.abs(phase - 0.5) - 1
        elseif waveform == "noise" then
            sample = (math.random() * 2 - 1) * 0.3
        end

        soundData:setSample(i, sample * volume * envelope)
    end

    return love.audio.newSource(soundData, "static")
end

local function generateChord(freqs, duration, volume, waveform)
    local sampleRate = 22050
    local samples = math.floor(sampleRate * duration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        local attack = math.min(1, t / 0.01)
        local release = math.min(1, (duration - t) / (duration * 0.4))
        local envelope = attack * release

        local sample = 0
        for _, freq in ipairs(freqs) do
            sample = sample + math.sin(2 * math.pi * freq * t)
        end
        sample = sample / #freqs

        soundData:setSample(i, sample * volume * envelope)
    end

    return love.audio.newSource(soundData, "static")
end

local function generateArpeggio(freqs, noteDuration, volume)
    local sampleRate = 22050
    local totalDuration = noteDuration * #freqs
    local samples = math.floor(sampleRate * totalDuration)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sampleRate
        local noteIdx = math.floor(t / noteDuration) + 1
        noteIdx = math.min(noteIdx, #freqs)
        local freq = freqs[noteIdx]
        local noteT = t - (noteIdx - 1) * noteDuration
        local attack = math.min(1, noteT / 0.005)
        local release = math.min(1, (noteDuration - noteT) / 0.03)
        local envelope = attack * release

        local sample = math.sin(2 * math.pi * freq * t) * 0.7
        sample = sample + math.sin(2 * math.pi * freq * 2 * t) * 0.2  -- harmonic

        soundData:setSample(i, sample * volume * envelope)
    end

    return love.audio.newSource(soundData, "static")
end

-------------------------------------------------------------------------------
-- INITIALIZE SOUNDS
-------------------------------------------------------------------------------
function Audio.init()
    -- Button click - short blip
    Audio.sounds.click = generateTone(800, 0.06, 0.25, "sine")

    -- Notification - ascending double tone
    Audio.sounds.notify = generateArpeggio({523, 659}, 0.08, 0.2)

    -- Success - happy chord
    Audio.sounds.success = generateChord({523, 659, 784}, 0.3, 0.2, "sine")

    -- Error/warning - descending tone
    Audio.sounds.error = generateArpeggio({400, 300}, 0.1, 0.2)

    -- Money - cash register
    Audio.sounds.money = generateArpeggio({1200, 1500, 1200, 1500}, 0.05, 0.15)

    -- Level up - ascending arpeggio
    Audio.sounds.levelup = generateArpeggio({523, 659, 784, 1047}, 0.1, 0.25)

    -- Award fanfare
    Audio.sounds.fanfare = generateArpeggio({523, 659, 784, 1047, 1319}, 0.12, 0.25)

    -- Review reveal - drum-like
    Audio.sounds.review = generateTone(200, 0.15, 0.2, "triangle", true)

    -- Week tick - subtle
    Audio.sounds.tick = generateTone(1000, 0.02, 0.05, "sine")

    -- New platform
    Audio.sounds.platform = generateArpeggio({440, 554, 659}, 0.15, 0.2)

    -- Game start
    Audio.sounds.start = generateArpeggio({262, 330, 392, 523}, 0.15, 0.25)

    -- Sad/bad
    Audio.sounds.sad = generateArpeggio({400, 350, 300, 250}, 0.12, 0.15)

    -- Type sound (typing during dev)
    Audio.sounds.type1 = generateTone(600, 0.02, 0.05, "noise")
    Audio.sounds.type2 = generateTone(700, 0.02, 0.05, "noise")
end

-------------------------------------------------------------------------------
-- PLAY
-------------------------------------------------------------------------------
function Audio.play(name)
    if not Audio.enabled then return end
    local sound = Audio.sounds[name]
    if sound then
        sound:stop()
        sound:setVolume(Audio.volume)
        sound:play()
    end
end

function Audio.toggle()
    Audio.enabled = not Audio.enabled
end

return Audio
