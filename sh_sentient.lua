tts_voices = {
	["bonzi"] = {
    	["female"] = "Adult Female #1, American English (TruVoice)",
    	["male"] = "Adult Male #1, American English (TruVoice)",
    	["mary"] = "Mary",
    	["sam"] = "Sam",
    	["mike"] = "Mike",
    	["female whisper"] = "Female Whisper",
    	["male whisper"] = "Male Whisper",
	},
	["google"] = {
		["en"] = "en",
		--["au"] = "au",
		["ja"] = "ja",
		["fr"] = "fr",
		["ru"] = "ru",
		["de"] = "de",
		["cs"] = "cs"
	},
	["murf"] = {
		["nate"] = "en-US-nate",
		["ethan"] = "en-CA-ethan",
		["hazel"] = "en-UK-hazel"
	}
}
tts_models = {
	["google"] = getTTSGoogle,
	["bonzi"] = getTTSBonzi,
	["murf"] = getTTSMurf
}

local char_to_hex = function(c)
	return string.format("%%%02X", string.byte(c))
end

local function getFirst(tbl)
	for _, t in pairs(tbl) do
		return _
	end
end
local function urlencode(url)
	if url == nil then
	    return
	end
	url = url:gsub("\n", "\r\n")
	url = url:gsub("([^%w ])", char_to_hex)
	url = url:gsub(" ", "+")
	url = string.Replace(url, " ", "+")
	url = string.Replace(url, ",", "%2C")
	return url
end


function getTTSBonzi(pl, text, voice, pitch, speed)
	text = string.sub(text , 1, 100 )
	text = urlencode(text)
	voice = urlencode(voice)
	print(voice)
	local url = "https://www.tetyys.com/SAPI4/SAPI4?text=" .. text  .. "&voice=" .. voice .. "&pitch=" .. (pitch or 150) .. "&speed=" .. (speed or 100)
	return url
end

function getTTSGoogle(pl, text, voice)
	text = string.sub(text , 1, 100 )
	voice = urlencode(voice)
	return "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=" .. voice .. "&q=" .. text
end

function getTTSMurf(pl, text, voice)
	text = string.sub(text , 1, 100 )
	text = urlencode(text)
	voice = urlencode(voice)
	local url = "https://murf.ai/Prod/anonymous-tts/audio?" .. "name=" .. voice .. "&text=" .. text
	return url
end