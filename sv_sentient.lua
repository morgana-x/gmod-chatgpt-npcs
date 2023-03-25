if not SERVER then return end
local AI_HEARING_RANGE = 400
util.AddNetworkString("chatgpt_entspeak")
util.AddNetworkString("chatgpt_enttextspeak")
CreateConVar( "openai_key", "", FCVAR_PROTECTED)


openAIAPIKEY = ""--"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"
local ai_key_convar = GetConVar("openai_key")
if not file.Exists("openai_key.txt", "DATA") then
    file.Write("openai_key.txt", "", "DATA")
end
ai_key_convar:SetString(file.Read("openai_key.txt","DATA"))
local lastOpenAIRequest = 0

cvars.AddChangeCallback("openai_key", function(convar_name, value_old, value_new)
    print(convar_name, value_old, value_new)
    file.Write("openai_key.txt", value_new)
end)
function getChatGPTResponse(prompt, model, temperature, max_tokens, cb)
    openAIAPIKEY = ai_key_convar:GetString()
    if not prompt then return end
    datajson = [[
        {"frequency_penalty":0.8,
         "max_tokens":]] .. tostring(max_tokens or 20) .. [[,
         "model":"]] .. (model or "text-davinci-003") ..  [[",
         "temperature":]] .. tostring(temperature or 0.7) ..[[,
         "prompt":"]] .. prompt .. [["
        }]]
   -- print(datajson)
    --print(":AFIJFA)JF_PAKF{AP}")
 --  print("sending ejafoaewijfg")
    HTTP({
        url= "https://api.openai.com/v1/completions", 
        method= "POST", 
        headers= { 
            ['Content-Type']= 'application/json',
            ["Authorization"] = "Bearer " .. openAIAPIKEY
        },
        success= function( code, body, headers )
          --  print("Cool stuff")
            --print(code)
            --print("sucess")
            --print(body)
            
            local decoded = util.JSONToTable(body)
            cb(decoded)
        end, 
        failed = function( err )
            print("error")
            print(err)
        end,
        type = 'application/json',
        body=datajson
    })
end

function ai_ent_tts(ent, text, model, voice)
    if not text then return end
    net.Start("chatgpt_entspeak")
    net.WriteEntity(ent) -- ent 
    net.WriteString(text) -- text
    net.WriteString(model or "google") -- model
    net.WriteString(voice or "") -- voice
    net.Broadcast()
end

function ai_chatgpt_simple(text, cb, max_tokens, temp)
    if not max_tokens then max_tokens = 30 end
    if not temp then temp = 0.8 end
    getChatGPTResponse(text, "text-davinci-003",temp,max_tokens,function(data)
        print("GOT RESPONSE")
        if not data["choices"] then return end
        cb(data["choices"][1]["text"])
    end)
end





local feeling_translation = {
    [D_ER] = "is not sure about",
    [D_HT] = "hates",
    [D_FR] = "fears",
    [D_LI] = "likes",
    [D_NU] = "is neutral to"
}

local state_translation = {
    [NPC_STATE_ALERT] = "alert and searching for enemies",
    [NPC_STATE_COMBAT] = "in combat",
    [NPC_STATE_NONE] = "acting normal",
    [NPC_STATE_INVALID] = "acting normal",
    [NPC_STATE_IDLE] = "idle",
    [NPC_STATE_DEAD] = "dead"
}

local combine = {
    ["CombineElite"] = true,
    ["CombinePrison"] = true,
    ["npc_metropolice"] = true,
    ["npc_combine_s"] = true,
    ["ShotgunSoldier"] = true,
}
local function generateName(ent)
    if ent:GetClass() == "npc_monk" then
        ent:SetNWString("ai_sentient_name", "Father Grigori")
        return "Father Grigori"
    end
    if ent:GetClass() == "npc_barney" then
        ent:SetNWString("ai_sentient_name", "Barney Calhoun")
        return "Barney Calhoun"
    end
    if ent:GetClass() == "npc_alyx" then
        ent:SetNWString("ai_sentient_name", "Alyx Vance")
        return "Alyx Vance"
    end
    if ent:GetClass() == "npc_eli" then
        ent:SetNWString("ai_sentient_name", "Eli Vance")
        return "Eli Vance"
    end
    if ent:GetClass() == "npc_kleiner" then
        ent:SetNWString("ai_sentient_name", "Kleiner")
        return "Kleiner"
    end
    if ent:GetClass() == "npc_mossman" then
        ent:SetNWString("ai_sentient_name", "Judith Mossman")
        return "Judith Mossman"
    end
    if ent:GetClass() == "npc_breen" then
        ent:SetNWString("ai_sentient_name", "Dr. Breen")
        return "Dr. Breen"
    end
    if ent:GetClass() == "npc_gman" then
        ent:SetNWString("ai_sentient_name", "G-Man")
        return "G-Man"
    end

    local name = ai_random_names_male[math.random(1, #ai_random_names_male)]

    if combine[ent:GetClass()] then
        name = "Officer " .. name
    end
    ent:SetNWString("ai_sentient_name", name)
    return name
end
local function getName(ent)
    if not IsValid(ent) then return "invalid" end
    if ent:IsPlayer() then
        return ent:Nick()
    end
   -- print("name: ")

   -- print(ent:GetNWString("ai_sentient_name", "unknown"))
    if  ent:GetNWString("ai_sentient_name", "unknown") == "unknown" then
        print("Generating name")
        return generateName(ent)
    end
    return  ent:GetNWString("ai_sentient_name")
end
local function affiliation_text(ent, attacker)
    local affiliation = feeling_translation[ent:Disposition(attacker)]
    local attacker_name = getName(attacker)
    local text = getName(ent) .. " " .. affiliation .. " " ..  attacker_name .. "."
    return text
end

local function state_text(ent)
    local state = state_translation[ent:GetNPCState()]
    if not state then return end
    local text = getName(ent) .. " is " .. state .. "."
    return text
end

local function addChatHistory(ent, text)
    if not chat_history[ent] then chat_history[ent] = { getName(ent) .. ": this is an example of how a response should be"} end
    if #chat_history[ent] > 5 then table.remove(chat_history[ent], 1) end
    table.insert(chat_history[ent], text)
end


local function addChatDeathHistory(ent, text)
    if not chat_death_history[ent] then chat_death_history[ent] = { getName(ent) .. ": this is an example of how a response should be"} end
    if #chat_death_history[ent] > 4 then table.remove(chat_death_history[ent], 1) end
    table.insert(chat_death_history[ent], text)
end
local function addChatImportantHistory(ent, text)
    if not chat_importanthistory[ent] then chat_importanthistory[ent] = { getName(ent) .. ": this is an example of how a response should be"} end
    if #chat_importanthistory[ent] > 7 then table.remove(chat_importanthistory[ent], 1) end
    table.insert(chat_importanthistory[ent], text)
end
local function getChatHistory(ent)
    local t = ""
    for _, a in ipairs(chat_death_history[ent] or {}) do
        local b = string.Replace(a, '"', "'")
        b = string.Replace(b, "\n", "")
        t = t .. b
    end
    for _, a in ipairs(chat_importanthistory[ent] or {}) do
        local b = string.Replace(a, '"', "'")
        b = string.Replace(b, "\n", "")
        t = t .. b
    end
    for _, a in ipairs(chat_history[ent] or {}) do
        local b = string.Replace(a, '"', "'")
        b = string.Replace(b, "\n", "")
        t = t .. b
    end

    print(t)
    return t
end

local function cleareChatHistory(ent)
    chat_death_history[ent]  = nil
    chat_importanthistory[ent] = nil
    chat_history[ent] = nil
end
function ai_ent_say(ent, text, ischat)
    if not IsValid(ent) then return end
    print(ent:Health())
    if ent:Health() <= 0 then print("DEAD") return end
    text = string.Replace(text, "\n", "")
    text = string.Replace(text, '"', "")
    ai_ent_tts(ent, text, "google", "en")
    local delay = (string.len(text) /4) + 0.3
    ent.lastAISay = CurTime() + delay

    print("DElay" .. tostring(delay))

    if not ischat then return end

    print("Sending chat to player")
    for _, pl in ipairs(player.GetHumans()) do

        if ent:GetPos():Distance(pl:GetPos()) > AI_HEARING_RANGE then print("TOO FAR AWAY") continue end

        net.Start("chatgpt_enttextspeak")
            net.WriteEntity(ent)
            net.WriteString(getName(ent))
            net.WriteString(text)
        net.Send(pl)
    end
    local chat_log = getName(ent) .. ": " .. text
    print(chat_log)
    local ents = ents.FindInSphere(ent:GetPos(), AI_HEARING_RANGE)
    for _, new_ent in ipairs(ents) do
        if not new_ent:IsNPC() or new_ent:IsNextBot() then continue end
        if new_ent:Health() <= 0 then continue end
       
        addChatHistory(new_ent,chat_log )
    end
   
    hook.Run("ai_ent_said", ent, text)
end

function ai_easy_say(ent, prompt, tokens, cb)

    local delay = 0
    if (ent.lastAISay or 0) > CurTime() then
        if ((ent.lastAiSay or 0) - CurTime() ) > 5 then return end
        delay = delay + ((ent.lastAiSay or 0)  - CurTime() )
    end
    print("DELAY: " .. delay )
    ent.queuedSay = prompt
    timer.Simple(delay, function()
        if not IsValid(ent) then return end
        if ent.queuedSay != prompt then return end
        ai_chatgpt_simple( prompt , function(text)

            if not IsValid(ent) then return end
            text = string.Replace(text, '"', "")
            text = string.Replace(text, "\n", "")
            text = string.Replace(text, "“", "")
            print(text)

            ai_ent_say(ent, text, true  )
            ent.lastAISay = CurTime() + (string.len(text) /8) + 0.3
            if cb then cb(text) end

        end, tokens)
    end)

end

function ai_ent_description_set(ent, text)
    ent:SetNWString("ai_ent_description", text)
end

function ai_ent_description_get(ent)
    ent:SetNWString("ai_ent_description", "")
end

chat_history = {}
chat_death_history = {}
chat_importanthistory = {}

last_ai_npc_talked_pain = 0

last_ai_npc_talked_mourn = 0


hook.Add("PostEntityTakeDamage", "npc_ent_damaged",function(ent, dmginfo, took)
    if not took then return end

    print("OUCH")
    if not (ent:IsNPC() or ent:IsNextBot()) then return end
    if ent:Health() <= 0 then
        print("dead xd")
        if last_ai_npc_talked_mourn > CurTime() then print("dead delay fail") return end
        last_ai_npc_talked_mourn = CurTime() + 0.5
        local ents = ents.FindInSphere(ent:GetPos(), AI_HEARING_RANGE)
        
    local correct_ents = {}
    for _, ent_other in ipairs(ents) do
    if not (ent_other:IsNPC() or ent_other:IsNextBot()) then continue end
        table.insert(correct_ents, ent_other)
    end
    table.Shuffle( correct_ents )
        for _, e in ipairs(correct_ents) do
            if not (e:IsNPC() or e:IsNextBot()) then continue end
            if e == ent then continue end
            if e:Health() <= 0 then continue end
            addChatImportantHistory(e, getName(ent) .. " has " .. ( (IsValid(dmginfo:GetAttacker()) and "been killed by " .. getName(dmginfo:GetAttacker())) or "died") )
            local tokens = 30
            if e:GetNPCState() == NPC_STATE_COMBAT then tokens = 15 end
            if e:GetNPCState() == NPC_STATE_PLAYDEAD then continue end
            
            if e:Disposition(ent) < D_LI then tokens = 15 end
            print("dead notify")
       
           -- if e:GetPos():Distance(ent:GetPos()) > 50 then continue end
            print("mourn")
           -- if not e.lastAISay then e.lastAISay = 0 end
          --  if e.lastAISay > CurTime() then return end
            local prompt = getName(ent) .. " has "..  ( (IsValid(dmginfo:GetAttacker()) and "been killed by " .. getName(dmginfo:GetAttacker())) or "died") .. ". They were a " ..  affiliation_text(e,ent) .. " to " .. getName(e) .. "." .. getName(e) .. "says: "
            ai_easy_say(e, prompt, tokens)
            break
        end
        return 
    end

    if last_ai_npc_talked_pain > CurTime() then return end

    if ( ent.lastAiSay or 0 ) > CurTime() then return end
    local name = ent:GetName()
    local attacker = dmginfo:GetAttacker()
    local chat_history = getChatHistory(ent)
    local p = chat_history .. getName(ent) .. " have been hurt!" ..  getName(ent) .. "says:"

    local attacker_name = getName(attacker)

    local ent_name = getName(ent)

    local ent_state = state_text(ent)

    local affiliation = affiliation_text(ent,attacker) 

    print("OW")

    if IsValid(attacker) and (attacker:GetPos():Distance(ent:GetPos()) <= AI_HEARING_RANGE) then
        p = chat_history .. ent_name .. " has been damaged by: " .. attacker_name  .. ". " .. ent_state .. " " ..  affiliation  .. " " ..  ent_name .. " says after being hurt:"
        addChatDeathHistory(ent, ent_name .. " has been damaged by " .. attacker_name)
    else
        addChatDeathHistory(ent, ent_name .. " has been damaged")
    end
        ai_easy_say(ent, p, math.random(10,25), function(text)
            last_ai_npc_talked_pain = CurTime() +  (string.len(text) /10) + 0.5
        end)


   
end)


hook.Add("PlayerSay", "npc_playersay", function(pl, text, teamchat)

    local tr = pl:GetEyeTraceNoCursor()
    if not IsValid(tr.Entity) then return end
    local ent = tr.Entity
    if not ent:IsNPC() or ent:IsNextBot() then return end
    if ent:Health() <= 0 then return end

    addChatHistory(ent, pl:Nick() .. ": " .. text)
    local chat_history = getChatHistory(ent)

    if not ent.lastAISay then ent.lastAISay = 0 end

    if not ent:Visible(pl) then return end
    ent.lastAISay = CurTime() + 3
    ent.currentPlayer = pl
    ent.lastTalkedCurrentPlayer = CurTime() + 6
    local ent_name = getName(ent)

    local ent_state = state_text(ent)

    local affiliation = affiliation_text(ent, pl) 
    local prompt = chat_history .. --[[pl:Nick().. " says " .. text .. " to " .. getName(ent) .. ". " ..]] affiliation .. " " .. ent_state .. " "  .. getName(ent) ..  " says:"
    ai_easy_say(ent,prompt, math.random(25,30))


   local ents = ents.FindInSphere(pl:GetPos(), AI_HEARING_RANGE)
    for _, ento in ipairs(ents) do
        if not ento:IsNPC() or ento:IsNextBot() then continue end
        if ento == ent then continue end
        if ento:Health() <= 0 then continue end
        addChatHistory(ento, pl:Nick() .. ": " .. text)
    end
   
end)

hook.Add("ai_ent_said", "npc_ai_converse", function(ent, text)
    local ents = ents.FindInSphere(ent:GetPos(), AI_HEARING_RANGE)
    print("TIME TO CONVERSE")
    --text = string.Replace(text, '"', "'")
    text = string.Replace(text, "\n", "")
    if IsValid(ent.currentPlayer) then return end

    local correct_ents = {}
    for _, ent_other in ipairs(ents) do
    if not (ent_other:IsNPC() or ent_other:IsNextBot()) then continue end
        table.insert(correct_ents, ent_other)
    end
    table.Shuffle( correct_ents )
    for _, ent_other in ipairs( correct_ents) do
        --if true then break end -------------------------- UNCOMMENT IF WANT CONVERSATOIN
        --print("NEW ENT")
        if not IsValid(ent_other) then continue end
        if not IsValid(ent) then return end

        if not (ent_other:IsNPC() or ent_other:IsNextBot()) then  continue end
        if ent_other == ent then continue end
        if getName(ent_other) == getName(ent) then continue end
        if ent_other:Health() <= 0 then print("daead") continue end
        if IsValid(ent.currenttalkEntity) and ent.currenttalkEntity ~= ent_other then print("occupied talking")  continue end
        if IsValid(ent_other.currenttalkEntity) and ent_other.currenttalkEntity ~= ent then print("occupied talking") continue end
        if IsValid(ent_other.currentPlayer) then print("occupied talking") continue end
        --local random = math.random(1, 100)
        --if random > 90 then print("random no") continue end
    
        if not ent_other.lastAISayToAi then ent_other.lastAISayToAi = 0 end
        if ent_other.lastAISayToAi > CurTime() then print("Spoke to soon") continue end

        if not ent_other.lastAISay then ent_other.lastAISay = 0 end

        if not ent_other.airesponses then ent_other.airesponses  = 0 end
        --if ent_other.lastAISay > CurTime() then return end

        ent_other.airesponses =  ent_other.airesponses + 1
        
        if ent_other.airesponses > 6 then ent_other.airesponses = 0; print("End conversation, chat too much!") break end -- CANCEL CONVERSATIOn

        print("Getting chat")
        timer.Simple( 0.1 + (string.len(text) / 8) , function()
            if not IsValid(ent) then return end
            if not IsValid(ent_other) then return end
            if ent:Health() <= 0 then return end
            if ent_other:Health() <= 0 then return end 
            ent_other.lastAISay = CurTime() + 0.1 + (string.len(text) / 8)

            ent_other.lastAISayToAi = CurTime() + 4
            ai_chatgpt_simple(getChatHistory(ent) ..  getName(ent) .. " says " .. text .. "."  .. affiliation_text(ent,ent_other) ..  " " .. state_text(ent) .. " " .. getName(ent_other) ..  " says:", function(text)
                if not IsValid(ent_other) then return end
                 ai_ent_say(ent_other,text, true)
            end, math.random(15,30))
        end)
        break


    end

end)

hook.Add("EntityRemoved", "npc_ai_clearhistory", function(ent)
    cleareChatHistory(ent)
end)


hook.Add("OnEntityCreated", "npc_ai_generatename", function(ent)
    if (ent:IsNPC() or ent:IsNextBot()) then generateName(ent)  end
end)

local function threaten_enemy(ent_other)
    if not IsValid(ent_other:GetEnemy()) then return end
    --print ("FOUND ENEMY")
  --  if (ent_other.beenconfronted or 0) > CurTime() then continue end
    if not ent_other.lastAIEnemyMessage then ent_other.lastAIEnemyMessage = 0 end
    if ent_other.lastAIEnemyMessage > CurTime() then  return end

    if not ent_other.lastAISay then ent_other.lastAISay = 0 end
    if ent_other.lastAISay > CurTime() then return end


    if (ent_other:GetEnemy().beenconfronted or 0) > CurTime() then return end
    if ent_other:GetPos():Distance(ent_other:GetEnemy():GetPos()) > AI_HEARING_RANGE then return end


   --[[ if ent_other:GetEnemyLastTimeSeen() - CurTime() > 10 and ent_other.lastAIEnemyEludedMessage > CurTime() then
        ent_other.lastAISay = CurTime() + 2

        ent_other.lastAIEnemyEludedMessage = CurTime() + 7

        print("Getting chat")
        addChatHistory( ent_other, getName(ent_other:GetEnemy()) .. " has been losy by " .. getName(ent_other) )
        ai_chatgpt_simple(  getName(ent_other) .. "'s target" ..   getName(ent_other:GetEnemy()) .. " has eluded " .. getName(ent_other) .. ". " .. affiliation_text(ent_other,ent_other:GetEnemy()) ..  " " .. state_text(ent_other) .. " "  .. getName(ent_other) .. " says:", function(text)
            if not IsValid(ent_other) then return end
            ai_ent_say(ent_other,text, true)

        end, 30)

        break
    end--]]
    if (ent_other:GetEnemyFirstTimeSeen() - CurTime()) > 2 then return end
   

    ent_other.lastAISay = CurTime() + 2

    ent_other.lastAIEnemyMessage = CurTime() + 7
    ent_other:GetEnemy().beenconfronted = CurTime() + 30
    --print("Getting chat")
    addChatHistory( ent_other, getName(ent_other:GetEnemy()) .. " has been spotted by  " .. getName(ent_other) )
    local prompt =  getName(ent_other) .. "'s target" ..   getName(ent_other:GetEnemy()) .. " has been spotted by " .. getName(ent_other) .. ". " .. affiliation_text(ent_other,ent_other:GetEnemy()) ..  " " .. state_text(ent_other) .. " "  .. getName(ent_other) .. " says:"
    ai_easy_say(ent_other,prompt, math.random(25,30))
    --[[ai_chatgpt_simple( prompt, function(text)
        if not IsValid(ent_other) then return end
        ai_ent_say(ent_other,text, true)

    end, 30)]]
    return true
end


local function bored(ent)
    --print("bored")
    if ent:GetNPCState() > 2 then return end
    if not ent.lastAISay then ent.lastAISay = 0 end
    if math.abs((ent.lastTalkedCurrentEntity or 0) - CurTime()) < 25 then return end
    if IsValid(ent.currenttalkEntity) then return end

    local ents = ents.FindInSphere(ent:GetPos(), AI_HEARING_RANGE)
    local correct_ents = {}
    for _, ent_other in ipairs(ents) do
    if not (ent_other:IsNPC() or ent_other:IsNextBot()) then  continue end
        if ent_other == ent then continue end
        table.insert(correct_ents, ent_other)
    end
    table.Shuffle( correct_ents )
    --print("bored2")
    for _, ent_other in ipairs( correct_ents) do
        if ent_other == ent then continue end
        if ent:Disposition(ent_other) <= 2 then continue end
        if not ent_other.lastAISay then ent_other.lastAISay = 0 end
        if IsValid(ent_other.currenttalkEntity) then continue end 
        if IsValid(ent_other.currentPlayer) then print("occupied talking") continue end
        if ent_other:GetPos():Distance(ent:GetPos()) > AI_HEARING_RANGE then continue end
        if math.abs(ent_other.lastAISay - CurTime()) < 15 then continue end
        ent_other.lastAISay = CurTime() + 0.5
        ent_other.currenttalkEntity = ent
        ent.currenttalkEntity = ent_other
        ent_other.lastTalkedCurrentEntity = CurTime() + 5
        ent.lastTalkedCurrentEntity = CurTime() + 5
        local prompt = getChatHistory(ent) .. getName(ent) .. " is bored so they will talk to " ..   getName(ent_other) .. ". " .. getName(ent) .. " says: " --[[ .. getName(ent_other) .. ":"]]
        ai_easy_say(ent,prompt, math.random(20, 30))
           --[[ ai_chatgpt_simple( prompt, function(text)
                if not IsValid(ent) then return end
                ent.lastAISay = CurTime() + 0.1 + (string.len(text) / 8)
                ai_ent_say(ent,text, true)
            end, 30)]]
        return true
    end
end
hook.Add("Tick", "npc_enemystuff", function()
    for _, ent_other in ipairs(ents.GetAll()) do

        if not (ent_other:IsNPC() or ent_other:IsNextBot()) then  continue end
        if ent_other == ent then continue end
        if ent_other:Health() <= 0 then continue end

        if ent_other.currentPlayer and ent_other.lastTalkedCurrentPlayer and CurTime() > ent_other.lastTalkedCurrentPlayer then
            ent_other.currentPlayer = nil
        end
  
        if ent_other.currenttalkEntity and ent_other.lastTalkedCurrentEntity and CurTime() > ent_other.lastTalkedCurrentEntity then
            ent_other.currenttalkEntity = nil
        end
        if threaten_enemy(ent_other) then continue end

        if bored(ent_other) then break end

    end

end)