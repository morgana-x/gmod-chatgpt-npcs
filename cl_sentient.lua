if SERVER then AddCSLuaFile() return end
local function getFirst(tbl)
	for _, t in pairs(tbl) do
		return _
	end
end

net.Receive("chatgpt_entspeak", function()
    print("Received speak!")
    local ent = net.ReadEntity()
    local text = net.ReadString()
    local model = net.ReadString()
    local voice = net.ReadString()
    local url = "http://translate.google.com/translate_tts?tl=en&client=t&q=" .. text
    local f = tts_models[model] or "google"
    if (not voice) or voice == "" then 
        voice =  getFirst(tts_voices[model] )
    end
    text = string.Replace(text, '"', "")
	url = f(ent, text, voice)
    print(url)

    sound.PlayURL( url , "3d", function( sound )
        if IsValid(ent.TTSchatSound) then
            ent.TTSchatSound:Stop()
        end
		if IsValid( sound ) then
			sound:SetPos( ply:GetPos() )
			sound:SetVolume( 5 )
			sound:Play()
			sound:Set3DFadeDistance( 120, 450 )
			ent.TTSchatSound = sound
		end

	end)
end)
local function getName(ent)
    if not IsValid(ent) then return "UNKNOWN" end
    if ent:IsPlayer() then
        return ent:Nick()
    end
    return  ent:GetNWString("ai_sentient_name", "UNKNOWN")
end
net.Receive("chatgpt_enttextspeak", function()
    print("Recieved text chat!")
    local ent = net.ReadEntity()
    local name = net.ReadString()
    local text = net.ReadString()
    text = string.Replace(text, "\n", "")
    chat.AddText(Color(255,255,100), getName(ent) .. ": ", Color(255,255,255), text)
end)

net.Receive("chatgpt_kill", function()
    print("Recieved text chat!")
    local ent = net.ReadString()()
    local victim = net.ReadString()
    text = string.Replace(text, "\n", "")
    chat.AddText(Color(255,255,100), ent, Color(255,0,0), " killed ",Color(255,255,100), victim )
end)


hook.Add( "Think", "sentientai_followsound", function()
	for k,v in pairs( ents.GetAll() ) do
		if not  IsValid( v.TTSchatSound ) then continue end
        if v:Health() <= 0 then v.TTSchatSound:Stop() continue end
		v.TTSchatSound:SetPos( v:GetPos() )
	end
end )

local function drawstuff(ent)
    if not (ent:IsNPC() or ent:IsNextBot()) then return end
    if ent:GetPos():Distance(LocalPlayer():GetPos()) > 250 then return end
    draw.SimpleText(getName(ent), "Trebuchet24", ScrW()/2, (ScrH()/2) - 20, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

end

hook.Add("HUDPaint", "npc_name", function()
    local tr = LocalPlayer():GetEyeTrace()
    if tr.Entity then
        drawstuff(tr.Entity)
    end
end)

hook.Add("EntityRemoved", "sentientai_stopsound", function(ent)
    if IsValid(ent.TTSchatSound) then ent.TTSchatSound:Stop() end
end)