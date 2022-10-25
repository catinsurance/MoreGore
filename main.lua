local GoreMod = RegisterMod("MoreGore", 1)
local SaveData = require("MoreGore.SaveManager")

local SHADERS = {
    VIGNETTE = "GoreMod_Vignette"
}
local VIGNETTE_UPDATE_PER_SECOND = 1 -- how much the vignette changes by to reach the target per second

GoreMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function() -- shader fix
    if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
        Isaac.ExecuteCommand("reloadshaders")
    end
end)

local ConsoleToggled = false
local Paused = false
local RoomTransition = false
local VignetteIntensity = 0
local VignetteIntensityTarget = 0

local VIGNETTE_COLORS = {
    Red = {
        0.988,
        0.05,
        0.05
    },
    Grey = {
        0.7,
        0.7,
        0.7
    },
}

local VignetteColorConfig = {
    "Red",
    "Grey"
}

local GibTypes = {
    "Blood",
    "Bone",
    "Guts"
}

local GibTypeProxy = {
    Blood = 1,
    Bone = 2,
    Guts = 3
}

local GORE_COUNT = { -- how many of each type of gore is there in the xml 
    Blood = 4,
    Bone = 2,
    Guts = 3
}

local VignetteColor = VIGNETTE_COLORS[VignetteColorConfig[1]]
local VignetteEnabled = 0

local CATEGORY_NAME = "MoreGore Settings"

local Config = { -- some of these settings arent used
    General = {
        LowHealthThreshold = 0.5,
    },
    Vignette = {
        Enabled = true,
        Color = VignetteColorConfig[1],
        Strength = 0.147,
    },
    Sounds = {
        Volume = 1,
    },
    Gore = {
        Bones = true,
        BloodTrail = true,
        Guts = true,
        BloodSplatter = true,
    },
    Extra = {
        ShakingAtCriticalHealth = false,
        HeavyBreathingAtCriticalHealth = false,
        FilmGrainAtCriticalHealth = false,
        CriticalHealthThreshold = 0.25,
    }
}

local function SpawnGibs(amount, amountVariance, type, intersperseSmall, origin) -- spawn custom gibs

    if type == GibTypeProxy.Blood and not Config.Gore.BloodSplatter then
        return
    end

    if type == GibTypeProxy.Bone and not Config.Gore.Bones then
        return
    end

    if type == GibTypeProxy.Guts and not Config.Gore.Guts then
        return
    end

    local rng = RNG()
    type = GibTypes[type]
    rng:SetSeed(Game():GetSeeds():GetNextSeed(), 35)

    for _ = 0, amount + (rng:RandomInt(amountVariance * 2) - amountVariance) do
        local goreType = type .. (rng:RandomInt(GORE_COUNT[type]) + 1)
        local gib = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CHAIN_GIB, 2, origin, Vector(0, 0), nil):ToEffect()
        local sprite = gib:GetSprite()
        
        gib.Velocity = Vector(rng:RandomFloat() * 10 - 5, rng:RandomFloat() * 10 - 5)
        sprite:Load("gfx/custom_gore.anm2", true)
        sprite.Rotation = rng:RandomFloat() * 360
        sprite:Play(goreType, true)
        
        if intersperseSmall and rng:RandomFloat() <= 0.4 then -- 40 perrcent chance to spawn a mini gib 
            goreType = type .. "Small" .. (rng:RandomInt(GORE_COUNT[type]) + 1)
            gib = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CHAIN_GIB, 2, origin, Vector(0, 0), nil):ToEffect()
            sprite = gib:GetSprite()
            
            gib.Velocity = Vector(rng:RandomFloat() * 10 - 5, rng:RandomFloat() * 10 - 5)
            sprite:Load("gfx/custom_gore.anm2", true)
            sprite.Rotation = rng:RandomFloat() * 360
            sprite:Play(goreType, true)
        end
    end
end

local function ModConfigMenuInit()
    if ModConfigMenu == nil then return end

    ModConfigMenu.AddText(CATEGORY_NAME, "Info", "MoreGore")
    ModConfigMenu.AddSpace(CATEGORY_NAME, "Info")
    ModConfigMenu.AddText(CATEGORY_NAME, "Info", "Version 1.0.0")
    ModConfigMenu.AddSpace(CATEGORY_NAME, "Info")
    ModConfigMenu.AddText(CATEGORY_NAME, "Info", "By Slugcat")

    -- GENERAL --

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "General",
        {
            Type = ModConfigMenu.OptionType.SCROLL,
            CurrentSetting = function ()
                return Config.General.LowHealthThreshold * 10
            end,
            Display = function ()
                return "Low Health Threshold: $scroll" .. math.floor(Config.General.LowHealthThreshold * 10) .. " " .. tostring(Config.General.LowHealthThreshold * 100) .. "%"
            end,
            OnChange = function (n)
                Config.General.LowHealthThreshold = n / 10
                SaveData:Get("General").LowHealthThreshold = Config.General.LowHealthThreshold
                
            end,
            Info = {
                "What percentage of your max HP should you be at to be considered low health?",
            }
        }
    )

    -- VIGNETTE --

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Vignette",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function()
                return Config.Vignette.Enabled
            end,
            Display = function()
                return "Vignette: " .. (Config.Vignette.Enabled and "Enabled" or "Disabled")
            end,
            OnChange = function(value)
                Config.Vignette.Enabled = value
                SaveData:Get("Vignette").Enabled = Config.Vignette.Enabled
            end,
            Info = {
                "Enables or disables the vignette effect.",
            }
        }
    )

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Vignette",
        {
            Type = ModConfigMenu.OptionType.SCROLL,
            CurrentSetting = function ()
                return Config.Vignette.Strength * 34
            end,
            Display = function ()
                return "Vignette Strength: $scroll" .. math.floor(Config.Vignette.Strength * 34) .. " " .. tostring(math.floor(Config.Vignette.Strength * 340)) .. "%"
            end,
            OnChange = function (n)
                Config.Vignette.Strength = n / 34
                SaveData:Get("Vignette").Strength = Config.Vignette.Strength
            end,
            Info = {
                "How strong should the vignette effect be?",
            }
        }
    )

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Vignette",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function ()
                for i, v in ipairs(VignetteColorConfig) do
                    if v == Config.Vignette.Color then
                        return i
                    end
                end

                return 0
            end,
            Minimum = 1,
            Maximum = #VignetteColorConfig,
            Display = function ()
                return "Vignette Color: " .. Config.Vignette.Color
            end,
            OnChange = function (n)
                Config.Vignette.Color = VignetteColorConfig[n]
                VignetteColor = VIGNETTE_COLORS[Config.Vignette.Color]
                SaveData:Get("Vignette").Color = Config.Vignette.Color
            end,
            Info = {
                "What color should the vignette be?",
                "Grey may be hard to see at times."
            }
        }
    )

    -- GORE --
    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Gore",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function()
                return Config.Gore.Bones
            end,
            Display = function()
                return "Bones: " .. (Config.Gore.Bones and "Enabled" or "Disabled")
            end,
            OnChange = function(value)
                Config.Gore.Bones = value
                SaveData:Get("Gore").Bones = Config.Gore.Bones
            end,
            Info = {
                "Can Isaac have his bones broken or ejected from his body?",
            }
        }
    )

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Gore",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function()
                return Config.Gore.BloodTrail
            end,
            Display = function()
                return "Blood Trail: " .. (Config.Gore.BloodTrail and "Enabled" or "Disabled")
            end,
            OnChange = function(value)
                Config.Gore.BloodTrail = value
                SaveData:Get("Gore").BloodTrail = Config.Gore.BloodTrail
            end,
            Info = {
                "Can Isaac leave a trail of blood behind him?",
            }
        }
    )

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Gore",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function()
                return Config.Gore.Guts
            end,
            Display = function()
                return "Guts: " .. (Config.Gore.Guts and "Enabled" or "Disabled")
            end,
            OnChange = function(value)
                Config.Gore.Guts = value
                SaveData:Get("Gore").Guts = Config.Gore.Guts
            end,
            Info = {
                "Can Isaac have his insides spilled out?",
            }
        }
    )

    ModConfigMenu.AddSetting(
        CATEGORY_NAME,
        "Gore",
        {
            Type = ModConfigMenu.OptionType.BOOLEAN,
            CurrentSetting = function ()
                return "Blood Splatter: " .. (Config.Gore.BloodSplatter and "Enabled" or "Disabled")
            end,
            OnChange = function (value)
                Config.Gore.BloodSplatter = value
                SaveData:Get("Gore").BloodSplatter = Config.Gore.BloodSplatter
            end,
            Info = {
                "Can Isaac get brutally slashed and shoot blood everywhere?"
            }
        }
    )
end

function GoreMod:OnRender()
    if not Game():IsPaused() then -- update vignette
        if VignetteIntensity ~= VignetteIntensityTarget then
            local diff = VignetteIntensityTarget - VignetteIntensity
            local change = diff * VIGNETTE_UPDATE_PER_SECOND / 60
            if math.abs(change) > math.abs(diff) then
                VignetteIntensity = VignetteIntensityTarget
            else
                VignetteIntensity = VignetteIntensity + change
            end
        end
    end
end

function GoreMod:GameUpdate()
    local lowestHealthPlayer, lowestHealthPercentage
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Game():GetPlayer(i)
        local data = player:GetData().GoreModFlags
        if not data then
            player:GetData().GoreModFlags = {}
            data = player:GetData().GoreModFlags
        end
        local redHeartPercentage = player:GetHearts() / player:GetEffectiveMaxHearts ()
        local soulHeartPercentage = player:GetSoulHearts() / player:GetMaxHearts()
        local totalHealthPercentage = redHeartPercentage + soulHeartPercentage
        if lowestHealthPercentage == nil or totalHealthPercentage < lowestHealthPercentage then
            lowestHealthPercentage = totalHealthPercentage
            lowestHealthPlayer = player
        end

        if Config.Gore.BloodTrail and totalHealthPercentage <= 0.5 then
            data.IsBleeding = true
        else
            data.IsBleeding = false
        end

        if data.IsBleeding and Config.Gore.BloodTrail then
            if player.FrameCount % 2 == 0 then
                local blood = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, player.Position, Vector(0, 0), player)
                blood.SpriteScale = Vector(0.5, 0.5)
            end
        end
    end

    if lowestHealthPlayer then -- update the vignette for the player with the lowest health
        if lowestHealthPercentage < Config.General.LowHealthThreshold then -- they have less than xx percent health, we will do the vignette
             -- make it more intense the loweer the percentage is 
            VignetteIntensityTarget = Config.Vignette.Strength * (1 - lowestHealthPercentage)
        else
            VignetteIntensityTarget = 0
        end
    end

    if Config.Vignette.Enabled then
        VignetteEnabled = 1
    else
        VignetteEnabled = 0
    end
end

function GoreMod:ShaderUpdate(shader) -- this part is really confusing, and i wrote it x_x
    if shader == SHADERS.VIGNETTE then
        local cid = Isaac.GetPlayer(0).ControllerIndex -- we can do this cuz only player 1 can pause

        local gravePressed = Input.IsButtonTriggered(Keyboard.KEY_GRAVE_ACCENT, cid)
        local pausePressed = Input.IsActionTriggered(ButtonAction.ACTION_PAUSE, cid) or Input.IsButtonTriggered(Keyboard.KEY_ESCAPE, cid)
        
        if RoomTransition and pausePressed then -- if we're in a room transition, dont pause
            if not Game():IsPaused() then
                RoomTransition = false
            else
                return {
                    Enabled = 1,
                    Strength = VignetteIntensity,
                    VignetteColor = VignetteColor
                }
            end
        end     

        if pausePressed then

            if not ConsoleToggled and Game():IsPaused() then -- if the console is not open and the game is paussed
                Paused = true
                ConsoleToggled = false


            elseif not ConsoleToggled and not Game():IsPaused() then -- if the console is not open and the game is not paused
                Paused = not Paused
            else -- if the console is open
                ConsoleToggled = false
            end

            
        end

        if gravePressed and not Paused then -- if the console is trying to be opened and the game is not paused
            ConsoleToggled = true
        end

        if not pausePressed and not Game():IsPaused() then -- if the game is not trying to be paused and the game is not paused
            Paused = false
            RoomTransition = false
        end

        return {
            Enabled = Paused and 0 or VignetteEnabled,
            Strength = VignetteIntensity,
            VignetteColor = VignetteColor
        }


    end
end

function GoreMod:EntityDMG(entity, amount, flags, sourceRef)
    if entity.Type == EntityType.ENTITY_PLAYER then
        local player = entity:ToPlayer()
        local data = player:GetData().GoreModFlags
        if not data then
            player:GetData().GoreModFlags = {}
            data = player:GetData().GoreModFlags
        end

        local redHeartPercentage = player:GetHearts() / player:GetEffectiveMaxHearts ()
        local soulHeartPercentage = player:GetSoulHearts() / player:GetMaxHearts()
        local totalHealthPercentage = redHeartPercentage + soulHeartPercentage
        if flags & DamageFlag.DAMAGE_FAKE == DamageFlag.DAMAGE_FAKE then -- if its fake damage dont bother
            return
        end

        if amount < 2 then -- normal hit
            if totalHealthPercentage >= 0.75 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_SPLAT, 0, player.Position, Vector.Zero, player)
                SpawnGibs(4, 1, GibTypeProxy.Blood, true, player.Position)
            elseif totalHealthPercentage <= 0.75 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
                SpawnGibs(4, 1, GibTypeProxy.Blood, true, player.Position)
            elseif totalHealthPercentage <= 0.5 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
                SpawnGibs(7, 2, GibTypeProxy.Blood, true, player.Position)
            end 
        else
            if totalHealthPercentage >= 0.75 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
                SpawnGibs(7, 2, GibTypeProxy.Blood, true, player.Position)
            elseif totalHealthPercentage <= 0.75 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
                SpawnGibs(7, 2, GibTypeProxy.Blood, true, player.Position)
            elseif totalHealthPercentage <= 0.5 then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
                SpawnGibs(10, 4, GibTypeProxy.Blood, true, player.Position)
            end 
        end

        if flags & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION then
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
            SpawnGibs(3, 0, GibTypeProxy.Bone, true, player.Position)
            SpawnGibs(3, 0, GibTypeProxy.Guts, true, player.Position)
            
            
        end

        if flags & DamageFlag.DAMAGE_CRUSH == DamageFlag.DAMAGE_CRUSH then
            SpawnGibs(10, 4, GibTypeProxy.Blood, true, player.Position)
            SpawnGibs(3, 0, GibTypeProxy.Bone, true, player.Position)
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
        end
    end    
end

---@param entity Entity
function GoreMod:PostKill(entity)
    if entity.Type == EntityType.ENTITY_PLAYER then
        local player = entity:ToPlayer()
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.LARGE_BLOOD_EXPLOSION, 0, player.Position, Vector.Zero, player)
        
        SpawnGibs(3, 0, GibTypeProxy.Bone, true, player.Position)
        SpawnGibs(3, 0, GibTypeProxy.Guts, true, player.Position)
        SpawnGibs(30, 4, GibTypeProxy.Blood, true, player.Position)

    end
end

function GoreMod:Cleanup()
    VignetteIntensity = 0
    VignetteIntensityTarget = 0
    Paused = false
    ConsoleToggled = false
    RoomTransition = false
end

function GoreMod:RoomTransition()
    -- if you paused while transitioning between rooms, the
    -- vignette will toggle, which will basically invert it until
    -- you do the same thing again. we can fix this by just
    -- turning off Paused after a room transition, because you
    -- cant enter a new room with the game paused 
    RoomTransition = true
end

local function ExistsOrTrue(value) -- lua tertiary operators are funky
    if value == nil then
        return true
    else
        return value
    end
end

function GoreMod:Setup()
    SaveData:Load()
    local General = SaveData:Get("General") 
    local Vignette = SaveData:Get("Vignette")
    local Gore = SaveData:Get("Gore")

    if not General then
        General = {}
        SaveData:Set("General", General)
    end

    if not Vignette then
        Vignette = {}
        SaveData:Set("Vignette", Vignette)
    end

    if not Gore then
        Gore = {}
        SaveData:Set("Gore", Gore)
    end

    Config.General.LowHealthThreshold = General.LowHealthThreshold or 0.5

    Config.Vignette.Color = Vignette.Color or VignetteColorConfig[1]
    Config.Vignette.Strength = Vignette.Strength or 0.147

    Config.Gore.BloodSplatter = ExistsOrTrue(Gore.BloodSplatter)
    Config.Gore.BloodTrail = ExistsOrTrue(Gore.BloodTrail)
    Config.Gore.Bone = ExistsOrTrue(Gore.Bone)
    Config.Gore.Guts = ExistsOrTrue(Gore.Guts)
end


SaveData:Init(GoreMod)

--  save data
GoreMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, SaveData.Flush)
GoreMod:AddCallback(ModCallbacks.MC_POST_GAME_END, SaveData.Flush)
GoreMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, GoreMod.Setup)

-- mod
ModConfigMenuInit()
GoreMod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, GoreMod.ShaderUpdate)
GoreMod:AddCallback(ModCallbacks.MC_POST_RENDER, GoreMod.OnRender)
GoreMod:AddCallback(ModCallbacks.MC_POST_UPDATE, GoreMod.GameUpdate)
GoreMod:AddCallback(ModCallbacks.MC_POST_GAME_END, GoreMod.Cleanup)
GoreMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, GoreMod.Cleanup)
GoreMod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, GoreMod.Cleanup)
GoreMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, GoreMod.RoomTransition)
GoreMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, GoreMod.EntityDMG)
GoreMod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, GoreMod.PostKill)
