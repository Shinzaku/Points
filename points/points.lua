--Based off the Pointwatch addon by Byrthnoth
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
addon.name      = "points";
addon.author    = "Shinzaku";
addon.version   = "2.2.8";
addon.desc      = "Various resource point and event tracking";
addon.link      = "https://github.com/Shinzaku/Ashita4-Addons/points";

require "common";
require "globals";
require "helpers";
local images = require("images");
local ffi = require("ffi");
local imgui = require("imgui");
local fonts = require("fonts");
local prims = require("primitives");
local settings = require("settings");
local config = require("config");
local scaling = require("scaling");

local player = AshitaCore:GetMemoryManager():GetPlayer();
local lastJob = 0;
local lastZone = 0;
local points = T{
    loaded = false,
    bar_is_open = T{ true, },
    window_suffix = "",
    use_both = false,
    settings = settings.load(DefaultSettings)
}
local guiimages = images.loadTextures(points.settings.theme);
local tokenType = "default";
local currTokens = {};
local globalTimer = 0;
local tValues = {};
local _timer = 0;
tValues.eventTimer = 0;
tValues.default = T{ lastXpKillTime = 0, xpKills = {}, xpChain = 0, estXpHour = 0, estMpHour = 0, xpTimer = 0, lastCpKillTime = 0, cpKills = {},
                    cpChain = 0, estCpHour = 0, estJpHour = 0, cpTimer = 0, sparks = 0, accolades = 0,
                    exp = { curr = 0, max = 0 },
                    limit = { curr = 0, points = 0, maxpoints = 0 },
                    capacity = { curr = 0, points = 0 },
                    mBreaker = false, lastEpKillTime = 0, epKills = {}, epChain = 0, estEpHour = 0, epTimer = 0,
                    mastery = { curr = 0, max = 0 },
                    };
tValues.dynamis = T{ keyItems = { false, false, false, false, false } };
tValues.abyssea = T{ pearlescent = 0, azure = 0, ruby = 0, amber = 0, golden = 0, silvery = 0, ebon = 0, };
tValues.assault = T{ objective = "-", timer = 0, };
tValues.nyzul = T{ floor = 0, objective = "-", };
tValues.voidwatch = T{ red = 0, blue = 0, green = 0, yellow = 0, white = 0, };
tValues.omen = T{ mainObjective = "-", addObjectives = {}, };
tValues.odyssey = T{ segments = 0, totalSegments = 0, izzat = 0, mMastery = 0, izCosts = {} };
tValues.sortie = T{ gallimaufry = 0 };
tValues.zoneTimer = os.clock();

local compactBar = T{};
compactBar.wrapper = fonts.new(WrapperSettings);
compactBar.wrapperIndent = "                  ";
compactBar.jobicon = fonts.new(JobIconSettings);
compactBar.jobiconIndent = "   ";
compactBar.textObjs = T{};

local debugText = "";
local zoning = false;

local function UpdateSettings(s)
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    -- Update the settings table..
    if (s ~= nil) then
        points.settings = s;
    end

    UpdateTokenList(zone, false, job);

    -- Reapply the font settings..
    for i,v in ipairs(compactBar.textObjs) do
        v:apply(points.settings.compact.font);
            if (currTokens[i] ~= nil and currTokens[i]:find("Bar]")) then
                v.font_height = points.settings.compact.font.font_height - 5;
                v.position_y = scaling.scale_h(2.5);
            else
                v.background.visible = false;
                v.position_y = 0;
            end
    end

    -- Save the current settings..
    settings.save();
end;

settings.register('settings', 'settings_update', UpdateSettings);

----------------------------------------------------------------------------------------------------s
-- func: load
-- desc: Event called when the addon is being loaded.
----------------------------------------------------------------------------------------------------
ashita.events.register("load", "load_callback1", function ()
    local playerEntity = GetPlayerEntity();
    if (player ~= nil and playerEntity ~= nil) then
        InitPointsBar();
    end
end);

----------------------------------------------------------------------------------------------------
-- func: unload
-- desc: Event called when the addon is being unloaded.
----------------------------------------------------------------------------------------------------
ashita.events.register("unload", "unload_callback1", function ()
    UpdateSettings();
    for i,v in ipairs(compactBar.textObjs) do
        v:destroy();
    end
    compactBar.jobicon:destroy();
    compactBar.wrapper:destroy();
end);

----------------------------------------------------------------------------------------------------
-- func: command
-- desc: Event called when the addon is processing a command.
----------------------------------------------------------------------------------------------------
ashita.events.register("command", "command_callback1", function (e)
    local args = e.command:args();
    if (#args == 0 or args[1] ~= "/points") then
        return;
    else
        e.blocked = true;
        if (args[2] == "config") then
            config.uiSettings.is_open[1] = not config.uiSettings.is_open[1];
        elseif (args[2] == "bothbars") then
            points.use_both = not points.use_both;
            if (points.use_both) then                
                PrintMsg("Displaying both bars for testing purposes");
                SetCompactVisibility(true);
            else
                PrintMsg("Reverting to single bar mode");
            end
        elseif (args[2] == "cleardebug") then
            PrintMsg("Clearing debug text");
            debugText = "";
        elseif (args[2] == nil or args[2] == "help") then
            PrintMsg("Help and available commands:\n" .. HelpString);
        end
    end
end);

----------------------------------------------------------------------------------------------------
-- func: packet_in
-- desc: Event called when the addon is processing incoming packets.
----------------------------------------------------------------------------------------------------
ashita.events.register("packet_in", "packet_in_callback1", function (e)
    if (e.id == 0x02D) then
        local pId = struct.unpack("I", e.data_modified, 0x05);
        local val = struct.unpack("I", e.data_modified, 0x11);
        local val2 = struct.unpack("I", e.data_modified, 0x15);
		local msgId = struct.unpack("H", e.data_modified, 0x19) % 1024;
        
        local killTime = os.clock();
        if (pId == GetPlayerEntity().ServerId) then
            if (msgId == 718 or msgId == 735) then
                if (tValues.default.lastCpKillTime ~= 0) then
                    table.insert(tValues.default.cpKills, { time=(killTime - tValues.default.lastCpKillTime), cp=val});
                else
                    table.insert(tValues.default.cpKills, { time=1, cp=val});
                end
                tValues.default.cpChain = val2;
                tValues.default.cpTimer = 30;
                tValues.default.lastCpKillTime = killTime;
                tValues.default.capacity.curr = tValues.default.capacity.curr + val;
                if (tValues.default.capacity.curr > 30000) then
                    tValues.default.capacity.curr = tValues.default.capacity.curr - 30000;
                end
            elseif (msgId == 8 or msgId == 105 or msgId == 253 or msgId == 371 or msgId == 372) then
                local jobLevel = player:GetMainJobLevel();
                if (tValues.default.lastXpKillTime ~= 0) then
                    table.insert(tValues.default.xpKills, { time=(killTime - tValues.default.lastXpKillTime), xp=val});
                else
                    table.insert(tValues.default.xpKills, { time=1, xp=val});
                end
                tValues.default.xpChain = val2;
                for i,v in ipairs(XPChainTimers) do
                    if (jobLevel <= v.lvl) then
                        if (tValues.default.xpChain >= 5) then
                            tValues.default.xpTimer = v.maxtime[6];
                            break;
                        else
                            tValues.default.xpTimer = v.maxtime[tValues.default.xpChain + 1];
                            break;
                        end
                    end
                end
                if (tValues.default.xpTimer == nil) then
                    tValues.default.xpTimer = 60;
                end
                tValues.default.lastXpKillTime = killTime;
                tValues.default.exp.curr = tValues.default.exp.curr + val;
                tValues.default.limit.curr = tValues.default.limit.curr + val;
                if (tValues.default.exp.curr > tValues.default.exp.max) then
                    tValues.default.exp.curr = tValues.default.exp.max - 1;
                end
                if (tValues.default.limit.curr > 10000) then
                    tValues.default.limit.curr = tValues.default.limit.curr % 10000;
                end
            elseif (msgId == 809 or msgId == 810) then
                if (tValues.default.lastEpKillTime ~= 0) then
                    table.insert(tValues.default.epKills, { time=(killTime - tValues.default.lastEpKillTime), ep=val});
                else
                    table.insert(tValues.default.epKills, { time=1, ep=val});
                end
                tValues.default.epChain = val2;
                tValues.default.epTimer = 30;
                tValues.default.lastEpKillTime = killTime;
                tValues.default.mastery.curr = tValues.default.mastery.curr + val;
            elseif (msgId == 719) then
                tValues.default.capacity.points = val;
            elseif (msgId == 50 or msgId == 368) then
                tValues.default.limit.points = val;
            end
        end
    elseif (e.id == 0x061) then
        tValues.default.exp.curr = struct.unpack("H", e.data_modified, 0x011);
        tValues.default.exp.max = struct.unpack("H", e.data_modified, 0x13);
        tValues.default.mastery.curr = struct.unpack("I", e.data_modified, 0x69);
        tValues.default.mastery.max = struct.unpack("I", e.data_modified, 0x6D);
		tValues.default.accolades = math.floor(e.data_modified:byte(0x5A) / 4) + e.data_modified:byte(0x5B) * 2 ^ 6 + e.data_modified:byte(0x5C) * 2 ^ 14;
    elseif (e.id == 0x063) then
        local offset = player:GetMainJob() * 6 + 13;
        if (e.data_modified:byte(5) == 2) then
            tValues.default.limit.curr = struct.unpack("H", e.data_modified, 9);
            tValues.default.limit.points = e.data_modified:byte(11) % 128;
            tValues.default.limit.maxpoints = e.data_modified:byte(0x0D) % 128;
        elseif (e.data_modified:byte(5) == 5) then
            tValues.default.capacity.curr = struct.unpack("H", e.data_modified, offset);
            tValues.default.capacity.points = struct.unpack("H", e.data_modified, offset + 2);;
        end
    elseif (e.id == 0x110) then
        tValues.default.sparks = struct.unpack("I", e.data, 0x05);
	elseif (e.id == 0x113) then
        tValues.default.sparks = struct.unpack("I", e.data, 0x75);
		tValues.default.accolades = struct.unpack('I', e.data, 0xE5);
    elseif (e.id == 0x00A) then
        zoning = true;
        tValues.zoneTimer = os.clock();
    elseif (e.id == 0x055) then
        local type = struct.unpack("B", e.data, 0x85);
        if (type == 3) then
            if (DynamisMapping[lastZone] ~= nil) then
                local dynaKI = struct.unpack("B", e.data, 0x06);
                local actualKI = {}
                actualKI[1] = bit.band(dynaKI, 2) > 0;
                actualKI[2] = bit.band(dynaKI, 4) > 0;
                actualKI[3] = bit.band(dynaKI, 8) > 0;
                actualKI[4] = bit.band(dynaKI, 16) > 0;
                actualKI[5] = bit.band(dynaKI, 32) > 0;
                UpdateDynamisKI(actualKI);
            end;
        end
    end
end);

ashita.events.register('text_in', 'text_in_callback1', function (e)
    if (e.mode > 600 and not e.injected) then
        local results;
        
        if (DynamisMapping[lastZone] ~= nil) then
            results = ashita.regex.search(e.message, MessageMatch.DynaTimeEntry);
            if (results ~= nil) then
                local timeset = tonumber(results[1][2]);
                timeset = timeset * 60;
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.DynaTimeUpdate);
            if (results ~= nil) then
                local timeLeft = tonumber(results[1][2]);
                local type = results[1][3];

                if (type == "minute") then
                    tValues.eventTimer = timeLeft * 60;
                else
                    tValues.eventTimer = timeLeft;
                end

                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.ObtainedKI);
            if (results ~= nil) then
                local kiName = results[1][2];
                
                if (kiName == "Crimson granules of time") then
                    UpdateDynamisKI({ true, nil, nil, nil, nil });
                elseif (kiName == "Azure granules of time") then
                    UpdateDynamisKI({ nil, true, nil, nil, nil });
                elseif (kiName == "Amber granules of time") then
                    UpdateDynamisKI({ nil, nil, true, nil, nil });
                elseif (kiName == "Alabaster granules of time") then
                    UpdateDynamisKI({ nil, nil, nil, true, nil });
                elseif (kiName == "Obsidian granules of time") then
                    UpdateDynamisKI({ nil, nil, nil, nil, true });
                end

                return;
            end
        elseif (AbysseaMapping[lastZone] ~= nil) then
            debugText = debugText .. "\n" .. e.message;
            results = ashita.regex.search(e.message, MessageMatch.AbysseaTime);
            if (results ~= nil) then
                local timeLeft = tonumber(results[1][2]);
                local type = results[1][3];

                if (type == "minute") then
                    tValues.eventTimer = timeLeft * 60;
                else
                    tValues.eventTimer = timeLeft;
                end

                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AbysseaRestLights1);
            if (results ~= nil) then
                tValues.abyssea.pearlescent = tonumber(results[1][2]);
                tValues.abyssea.ebon = tonumber(results[1][3]);
                tValues.abyssea.golden = tonumber(results[1][4]);
                tValues.abyssea.silvery = tonumber(results[1][5]);
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AbysseaRestLights2);
            if (results ~= nil) then
                tValues.abyssea.azure = tonumber(results[1][2]);
                tValues.abyssea.ruby = tonumber(results[1][3]);
                tValues.abyssea.amber = tonumber(results[1][4]);
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AbysseaLights);
            if (results ~= nil) then
                UpdateAbysseaLights(results[1][2], results[1][3]);
                return;
            end
        elseif (AssaultMapping[lastZone] ~= nil or NyzulMapping[lastZone] ~= nil) then
            results = ashita.regex.search(e.message, MessageMatch.AssaultObj);
            if (results ~= nil) then
                tValues.assault.objective = results[1][2] .. " -> " .. string.sub(results[1][4], 1, string.len(results[1][4]) - 1);
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.NyzulObj);
            if (results ~= nil) then
                tValues.nyzul.objective = results[1][2];
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.NyzulFloor);
            if (results ~= nil) then
                tValues.nyzul.floor = results[1][2];
                return;
            end;
            results = ashita.regex.search(e.message, MessageMatch.AssaultTime);
            if (results ~= nil) then
                local timeLeft = tonumber(results[1][2]);
                local type = results[1][3];

                if (type == "minute") then
                    tValues.eventTimer = timeLeft * 60;
                else
                    tValues.eventTimer = timeLeft;
                end
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AssaultTimeUpdate)
            if (results ~= nil) then
                local timeLeft = tonumber(results[1][2]);
                local type = results[1][3];

                if (type == "minute") then
                    tValues.eventTimer = timeLeft * 60;
                else
                    tValues.eventTimer = timeLeft;
                end
                return;
            end
        end
    end
end);

----------------------------------------------------------------------------------------------------
-- func: d3d_present
-- desc: Event called when the Direct3D device is presenting a scene.
----------------------------------------------------------------------------------------------------
ashita.events.register("d3d_present", "present_cb", function ()
    if (not points.loaded and GetPlayerEntity() ~= nil) then
        InitPointsBar();
        return;
    elseif (GetPlayerEntity() == nil) then
        return;
    end;

    player = AshitaCore:GetMemoryManager():GetPlayer();
    local currJob = player:GetMainJob();
    local currZone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    if (player.isZoning or currJob == 0 or (GetPlayerEntity().StatusServer == 4 and points.settings.hide_on_event[1] == true)) then
        if (compactBar.wrapper:GetVisible()) then
            SetCompactVisibility(false);
        end
        return;
    elseif (not player.isZoning and zoning) then
        zoning = false;
        UpdateTokenList(currZone, true);
    elseif ((points.settings.use_compact_ui[1] and (not compactBar.wrapper:GetVisible() or not compactBar.textObjs[1]:GetVisible())) or points.use_both) then
        SetCompactVisibility(true);
    elseif (not points.settings.use_compact_ui[1] and (compactBar.wrapper:GetVisible() or compactBar.textObjs[1]:GetVisible()) and not points.use_both) then
        SetCompactVisibility(false);
    elseif (currZone ~= nil and currZone ~= 0 and currZone ~= lastZone) then
        lastZone = currZone;
    end
    if (currJob ~= lastJob and currJob ~= 0) then
        lastJob = currJob;
        UpdateTokenList(currZone, true, currJob);
    end
    -----------------------------
    -- Recalculate estimations --
    -----------------------------
    if (os.time() >= _timer + 1) then
        _timer = os.time();
        
        -- Double check for job mastery ---
        if (player:GetJobPointsSpent(currJob) >= 2100 and tokenType == "default") then
            tValues.default.mBreaker = player:HasKeyItem(GetKeyItemFromName("master breaker"));
            if (tValues.default.mBreaker) then
                UpdateTokenList(currZone, false, currJob);
            end
        end

        if (#tValues.default.xpKills > 50) then
            table.remove(tValues.default.xpKills, 1);
        end
        if (#tValues.default.cpKills > 50) then
            table.remove(tValues.default.cpKills, 1);
        end
        if (math.floor(os.clock()) > globalTimer) then
            globalTimer = math.floor(os.clock());
    
            CalculateEstimates();
            TickTimers();
        end
    end
    
    if (points.settings.rate_reset_timer > 0) then
        if (tValues.default.lastXpKillTime > 0) then
            if (tValues.default.lastXpKillTime >= os.clock() + points.settings.rate_reset_timer) then
                ResetXPCPRates();
            end
        elseif (tValues.default.lastCpKillTime > 0) then
            if (tValues.default.lastCpKillTime >= os.clock() + points.settings.rate_reset_timer) then
                ResetXPCPRates();
            end
        end
    end

    ------------------------------------------------
    -- Points info bars --
    ------------------------------------------------
    DrawPointsBar(currJob);
    UpdateCompactBar(currJob);

    -------------------
    -- Config window --
    -------------------
    config.drawWindow(points.settings);
    if (config.uiSettings.changed) then
        UpdateSettings();
        config.uiSettings.changed = false;
    end
end);

function DrawPointsBar(currJob)
    local jobLevel = player:GetMainJobLevel();
    local mastered = player:GetJobPointsSpent(currJob) == 2100;
    if (tValues.default.mBreaker and mastered) then
        jobLevel = player:GetMasteryJobLevel();
    end
    if (not points.settings.use_compact_ui[1] or points.use_both) then
        imgui.SetNextWindowSize({ -1, 32 * points.settings.font_scale }, ImGuiCond_FirstUseEver);
        imgui.SetNextWindowPos({ points.settings.bar_x, points.settings.bar_y }, ImGuiCond_FirstUseEver);
    end
    imgui.PushStyleColor(ImGuiCol_WindowBg, points.settings.colors.bg);
    imgui.PushStyleColor(ImGuiCol_Border, points.settings.colors.bgBorder);
    imgui.PushStyleColor(ImGuiCol_BorderShadow, { 1.0, 0.0, 0.0, 1.0});
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    if((not points.settings.use_compact_ui[1] or points.use_both) and imgui.Begin("PointsBar" .. points.window_suffix, points.bar_is_open, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize))) then
        imgui.PopStyleColor(3);
        imgui.PushStyleColor(ImGuiCol_Text, points.settings.colors.mainText);
        imgui.SetWindowFontScale(points.settings.font_scale);
        -----------------------------------------
        -- Left image icon, with job and level --
        -----------------------------------------
        if (points.settings.use_job_icon[1] == true) then
            local imgOffsetX = (1.0 / (384 / 64)) * math.fmod(currJob - 1.0, 6.0);
            local imgOffsetY = 0.25 * math.floor((currJob - 1) / 6.0);
            local imgOffsetX2 = imgOffsetX + (1.0 / (384 / 64.0));
            local imgOffsetY2 = imgOffsetY + 0.25;
            imgui.Image(tonumber(ffi.cast("uint32_t", guiimages.jobicons)), { 64 * points.settings.font_scale, 32 * points.settings.font_scale }, { imgOffsetX, imgOffsetY }, { imgOffsetX2, imgOffsetY2 }, { 1, 1, 1, 1 }, { 1, 1, 1, 0 });
            imgui.SetCursorPos({ 43 * points.settings.font_scale, 0 });
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 5 });
            imgui.AlignTextToFramePadding();
            imgui.Text(string.format("%02d", jobLevel));
            imgui.PopStyleVar(1);
            imgui.SameLine();
            imgui.SetCursorPos({ 72 * points.settings.font_scale, 0 });
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 10 * points.settings.font_scale });
            imgui.AlignTextToFramePadding();
            imgui.PopStyleVar(1);
        else
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 10 * points.settings.font_scale });
            imgui.AlignTextToFramePadding();
            imgui.PopStyleVar(1);
            imgui.SetCursorPos({ 10 * points.settings.font_scale, 0 });
            imgui.Text(string.format("Lv.%02d", jobLevel));
            imgui.SameLine();
        end

        --------------------
        --- Main text bar --
        --------------------        
        for i,v in pairs(currTokens) do
            if (i > 1) then
                imgui.SameLine();
            end

            ParseToken(i, v);
        end

        imgui.SameLine();
        imgui.Text(" ");
        imgui.PopStyleColor(1);
        imgui.SetWindowFontScale(1.0);
        if (not imgui.IsWindowHovered() and not imgui.IsMouseDown(ImGuiMouseButton_Left)) then
            local newX, newY = imgui.GetWindowPos();
            if (points.settings.bar_x ~= newX or points.settings.bar_y ~= newY) then
                points.settings.bar_x = newX;
                points.settings.bar_y = newY;
                config.uiSettings.changed = true;
            end
        end
        imgui.End();
    else
        imgui.PopStyleColor(3);
    end
    imgui.PopStyleVar(1);
end

function LoadCompactBar()
    compactBar.wrapper.auto_resize = false;
    compactBar.wrapper.background.visible = true;
    compactBar.wrapper.background.color = RGBAtoHex(points.settings.colors.bg);
    compactBar.wrapper.background.border_flags = 15;
    compactBar.wrapper.background.border_color = RGBAtoHex(points.settings.colors.bgBorder);
    local bSizes = RECT.new();
    bSizes.top = 1.0;
    bSizes.left = 1.0;
    bSizes.right = 1.0;
    bSizes.bottom = 1.0;
    compactBar.wrapper.background.border_sizes = bSizes;
    compactBar.wrapper.background.border_visible = true;
    compactBar.wrapper.lockedz = true;
    compactBar.wrapper.position_x = scaling.scale_w(points.settings.compact.x);
    compactBar.wrapper.position_y = scaling.scale_h(points.settings.compact.y);
    compactBar.wrapper.visible = points.settings.use_compact_ui[1];

    compactBar.jobicon.auto_resize = false;
    compactBar.jobicon.can_focus = false;
    compactBar.jobicon.font_height = scaling.scale_f(10);
    compactBar.jobicon.font_family = "Consolas";
    compactBar.jobicon.color_outline = 0xFF000000;
    compactBar.jobicon.background.visible = true;
    compactBar.jobicon.background:SetTextureFromFile(string.format("%s/themes/%s/ffxi-jobicons-compact.png", addon.path, points.settings.theme));
    compactBar.jobicon.background.width = 64;
    compactBar.jobicon.background.height = 16;
    compactBar.jobicon.background.scale_x = scaling.scaled.w;
    compactBar.jobicon.background.scale_y = scaling.scaled.h;
    compactBar.jobicon.visible = true;
    compactBar.jobicon.parent = compactBar.wrapper;

    -- Default bar items --
    for i=1,#currTokens,1 do
        local newFont = fonts.new(points.settings.compact.font);
        newFont.font_height = points.settings.compact.font.font_height;
        newFont.bold = false;
        newFont.can_focus = false;
        newFont.locked = true;
        newFont.visible = points.settings.use_compact_ui[1];
        newFont.parent = compactBar.wrapper;
        if (currTokens[i]:find("Bar]")) then
            newFont.font_height = points.settings.compact.font.font_height - 5;
            newFont.position_y = scaling.scale_h(2.5);
        end
        compactBar.textObjs:insert(newFont);
    end
end

function UpdateCompactBar(currJob)
    local totalSize = SIZE.new();
    if (points.settings.use_job_icon[1]) then
        totalSize.cx = math.floor(scaling.scale_w(64 + points.settings.compact.hPadding));
    else
        totalSize.cx = math.floor(scaling.scale_w(32 + points.settings.compact.hPadding));
    end
    totalSize.cy = math.floor(scaling.scale_h(16));

    if (#compactBar.textObjs > #currTokens) then
        for i=#currTokens + 1,#compactBar.textObjs,1 do
            compactBar.textObjs[i]:destroy();
            compactBar.textObjs[i] = nil;
        end
    elseif (#compactBar.textObjs < #currTokens) then
        for i=#compactBar.textObjs + 1,#currTokens,1 do
            local newFont = fonts.new(points.settings.compact.font);
            newFont.font_height = points.settings.compact.font.font_height;
            newFont.can_focus = false;
            newFont.locked = true;
            newFont.lockedz = true;
            newFont.visible = points.settings.use_compact_ui[1];
            newFont.parent = compactBar.wrapper;
            if (currTokens[i]:find("Bar]")) then
                newFont.font_height = points.settings.compact.font.font_height - 5;
                newFont.position_y = scaling.scale_h(2.5);
            end
            compactBar.textObjs:insert(newFont);
        end
    end

    ------------------------------------------
    -- Job Icon display
    ------------------------------------------
    local jobLevel = player:GetMainJobLevel();
    local mastered = player:GetJobPointsSpent(currJob) == 2100;
    if (points.settings.use_job_icon[1]) then
        local imgOffsetX = 64 * math.fmod(currJob - 1.0, 6.0);
        local imgOffsetY = 17 * math.floor((currJob - 1) / 6.0);
        compactBar.jobicon.background.texture_offset_x = imgOffsetX;
        compactBar.jobicon.background.texture_offset_y = imgOffsetY;
        if (tValues.default.mBreaker and mastered) then
            jobLevel = player:GetMasteryJobLevel();
        end
        compactBar.jobicon.background.visible = true;
        compactBar.jobicon.text = compactBar.jobiconIndent .. string.format("%02d", jobLevel);
    else
        compactBar.jobicon.background.visible = false;
        compactBar.jobicon.text = string.format("Lv.%02d", jobLevel);
    end
    -------------------------------------------
    -- These values are already being calculated while default bar is displayed; Ensures the tokens are parsed otherwise --
    if (points.settings.use_compact_ui[1] and not points.use_both) then
        for i,v in pairs(currTokens) do
            ParseToken(i, v);
        end
    end
    -------------------------------------------
    local lastSize = SIZE.new();
    compactBar.wrapper.background.color = RGBAtoHex(points.settings.colors.bg);
    compactBar.wrapper.background.border_color = RGBAtoHex(points.settings.colors.bgBorder);
    for i,v in pairs(compactBar.textObjs) do
        v.color = RGBAtoHex(points.settings.colors.mainText);
        if (not currTokens[i]:find("Bar]") and v.font_height ~= points.settings.compact.font.font_height) then
            v.font_height = points.settings.compact.font.font_height;
        elseif (currTokens[i]:find("Bar]") and v.font_height ~= points.settings.compact.font.font_height - 5) then
            v.font_height = points.settings.compact.font.font_height - 5;
        end
        if (v.font_family ~= points.settings.compact.font.font_family) then
            v.font_family = points.settings.compact.font.font_family;
        end

        v:GetTextSize(lastSize);
        if (i > 1 and v.text ~= "") then
            v.position_x = totalSize.cx + points.settings.compact.hPadding;
            totalSize.cx = totalSize.cx + lastSize.cx + points.settings.compact.hPadding;
        elseif (v.text ~= "") then
            v.position_x = totalSize.cx;
            totalSize.cx = totalSize.cx + lastSize.cx;
        end
        totalSize.cy = math.floor(scaling.scale_h(lastSize.cy));
    end
    compactBar.wrapper.background.width = totalSize.cx + points.settings.compact.hPadding;
    if (points.settings.compact.font.font_height > 11) then
        compactBar.wrapper.background.height = math.floor(scaling.scale_h(totalSize.cy));
    else
        compactBar.wrapper.background.height = math.floor(scaling.scale_h(16));
    end;

    compactBar.wrapper.position_x = points.settings.compact.x;
    compactBar.wrapper.position_y = points.settings.compact.y;
end

function SetCompactVisibility(val)
    if (val ~= nil) then
        compactBar.wrapper.visible = val;
        compactBar.jobicon.visible = val;
        for i,v in pairs(compactBar.textObjs) do
            v.visible = val;
        end
    end
end

function InitTrackedValues()
    local currJob = player:GetMainJob();
    tValues.default.mBreaker = player:HasKeyItem(GetKeyItemFromName("master breaker"));
    local sparksPtr = ashita.memory.find('FFXiMain.dll',  0,  '8B4C240C8B4104??????????',  0,  0);
    local sparksAddy = ashita.memory.read_uint32(sparksPtr + 8);
    tValues.default.sparks = ashita.memory.read_uint32(sparksAddy);
    tValues.default.accolades = player:GetUnityPoints();
    tValues.default.exp.curr = player:GetExpCurrent();
    tValues.default.exp.max = player:GetExpNeeded();
    tValues.default.limit.curr = player:GetLimitPoints();
    tValues.default.limit.points = player:GetMeritPoints();
    tValues.default.limit.maxpoints = player:GetMeritPointsMax();
    tValues.default.capacity.curr = player:GetCapacityPoints(currJob);
    tValues.default.capacity.points = player:GetJobPoints(currJob);
    tValues.default.mastery.curr = player:GetMasteryExp();
    tValues.default.mastery.max = player:GetMasteryExpNeeded();
    local dynaKI = {};
    dynaKI[1] = player:HasKeyItem(GetKeyItemFromName("crimson granules of time"));
    dynaKI[2] = player:HasKeyItem(GetKeyItemFromName("azure granules of time"));
    dynaKI[3] = player:HasKeyItem(GetKeyItemFromName("amber granules of time"));
    dynaKI[4] = player:HasKeyItem(GetKeyItemFromName("alabaster granules of time"));
    dynaKI[5] = player:HasKeyItem(GetKeyItemFromName("obsidian granules of time"));
    UpdateDynamisKI(dynaKI);
end

function CalculateEstimates()
    if (tValues.default.xpTimer > 0) then
        tValues.default.xpTimer = tValues.default.xpTimer - 1;
    else
        tValues.default.xpChain = 0;
    end
    if (tValues.default.cpTimer > 0) then
        tValues.default.cpTimer = tValues.default.cpTimer - 1;
    else
        tValues.default.cpChain = 0;
    end
    if (tValues.default.epTimer > 0) then
        tValues.default.epTimer = tValues.default.epTimer - 1;
    else
        tValues.default.epChain = 0;
    end

    if (#tValues.default.xpKills > 0) then
        local avgXP = 0;
        local avgTime = 0;
        for i,v in pairs(tValues.default.xpKills) do
            avgXP = avgXP + v.xp;
            avgTime = avgTime + v.time;
        end
        avgXP = avgXP / #tValues.default.xpKills;
        avgTime = (avgTime + (os.clock() - tValues.default.lastXpKillTime)) / (#tValues.default.xpKills + 1);
        tValues.default.estXpHour = ((60 / avgTime) * avgXP) * 60;
        tValues.default.estMpHour = tValues.default.estXpHour / 10000;
    end
    if (#tValues.default.cpKills > 0) then
        local avgCP = 0;
        local avgTime = 0;
        for i,v in pairs(tValues.default.cpKills) do
            avgCP = avgCP + v.cp;
            avgTime = avgTime + v.time;
        end
        avgCP = avgCP / #tValues.default.cpKills;
        avgTime = (avgTime + (os.clock() - tValues.default.lastCpKillTime)) / (#tValues.default.cpKills + 1);
        tValues.default.estCpHour = (((60 / avgTime) * avgCP) * 60);
        tValues.default.estJpHour = tValues.default.estCpHour / 30000;
    end
    if (#tValues.default.epKills > 0) then
        local avgEP = 0;
        local avgTime = 0;
        for i,v in pairs(tValues.default.epKills) do
            avgEP = avgEP + v.ep;
            avgTime = avgTime + v.time;
        end
        avgEP = avgEP / #tValues.default.epKills;
        avgTime = (avgTime + (os.clock() - tValues.default.lastEpKillTime)) / (#tValues.default.epKills + 1);
        tValues.default.estEpHour = (((60 / avgTime) * avgEP) * 60);
    end
end

function TickTimers()
    if (tValues.eventTimer > 0) then
        tValues.eventTimer = tValues.eventTimer - 1;
    end
end

function UpdateTokenList(zoneId, reset, jobId)
    if (DynamisMapping[zoneId] ~= nil and points.settings.token_enabled_dynamis[1]) then
        currTokens = ashita.regex.split(points.settings.token_order_dynamis, " ");
        tokenType = "dynamis";
        if (reset) then
            tValues.eventTimer = 3600;
        end
    elseif (AbysseaMapping[zoneId] ~= nil and points.settings.token_enabled_abyssea[1]) then
        currTokens = ashita.regex.split(points.settings.token_order_abyssea, " ");
        tokenType = "abyssea";
        if (reset) then
            tValues.abyssea.amber = 0;
            tValues.abyssea.azure = 0;
            tValues.abyssea.ebon = 0;
            tValues.abyssea.golden = 0;
            tValues.abyssea.pearlescent = 0;
            tValues.abyssea.ruby = 0;
            tValues.abyssea.silvery = 0;
            tValues.eventTimer = 300;
        end
    elseif (AssaultMapping[zoneId] ~= nil and points.settings.token_enabled_assault[1]) then
        currTokens = ashita.regex.split(points.settings.token_order_assault, " ");
        tokenType = "assault";
        if (reset) then
            tValues.assault.objective = "-";
            tValues.eventTimer = 1800;
        end
    elseif (NyzulMapping[zoneId] ~= nil and points.settings.token_enabled_nyzul[1]) then
        currTokens = ashita.regex.split(points.settings.token_order_nyzul, " ");
        tokenType = "nyzul";
        if (reset) then
            tValues.nyzul.objective = "-";
            tValues.nyzul.floor = 0;
        end
    else
        local currJob = player:GetMainJob();
        local mastered = player:GetJobPointsSpent(currJob) == 2100;
        if (jobId) then
            mastered = player:GetJobPointsSpent(jobId) == 2100;
        end
        if (tValues.default.mBreaker and mastered and points.settings.token_enabled_mastered[1]) then
            currTokens = ashita.regex.split(points.settings.token_order_mastered, " ");
            tokenType = "mastered";
        else
            currTokens = ashita.regex.split(points.settings.token_order_default, " ");
            tokenType = "default";
        end
        if (reset) then
            for i,v in pairs(tValues.dynamis.keyItems) do
                v = false;
            end
            tValues.eventTimer = 0;
        end
    end
    
    if (jobId) then
        tValues.default.exp.curr = player:GetExpCurrent();
        tValues.default.exp.max = player:GetExpNeeded();
        tValues.default.capacity.curr = player:GetCapacityPoints(jobId);
        tValues.default.capacity.points = player:GetJobPoints(jobId);
        tValues.default.mastery.curr = player:GetMasteryExp();
        tValues.default.mastery.max = player:GetMasteryExpNeeded();
    end
    
    if ((#tValues.default.xpKills > 0 or #tValues.default.cpKills > 0) and reset) then
        ResetXPCPRates();
    end
end

function ResetXPCPRates()    
    tValues.default.xpKills = {};
    tValues.default.lastXpKillTime = 0;
    tValues.default.xpChain = 0;
    tValues.default.xpTimer = 0;
    tValues.default.estXpHour = 0;
    tValues.default.estMpHour = 0;
    tValues.default.cpKills = {};
    tValues.default.lastCpKillTime = 0;
    tValues.default.cpChain = 0;
    tValues.default.cpTimer = 0;
    tValues.default.estCpHour = 0;
    tValues.default.estJpHour = 0;
    tValues.default.lastEpKillTime = 0;
    tValues.default.epKills = {};
    tValues.default.epChain = 0;
    tValues.default.estEpHour = 0;
    tValues.default.epTimer = 0;
end

function UpdateDynamisKI(kItems)
    if (DynamisMapping[lastZone] ~= nil) then
        for i,v in pairs(kItems) do
            if (v ~= nil) then
                if (not tValues.dynamis.keyItems[i] and v) then
                    tValues.eventTimer = tValues.eventTimer + DynamisMapping[lastZone][i];
                end
                tValues.dynamis.keyItems[i] = v;
            end
        end
    end
end;

function UpdateAbysseaLights(strength, light)
    tValues.abyssea[light] = math.min(tValues.abyssea[light] + AbysseaLightEstimates[light][strength], AbysseaLightEstimates[light].max);
end;

function PrintMsg(msg)
    print(string.format("[\30\08Points\30\1] \30\67%s", msg));
end;

function ParseToken(i, token)
    local jobLevel = player:GetMainJobLevel();
    local currJob = player:GetMainJob();
    local sep = points.settings.num_separator;

    if (compactBar.textObjs[i] == nil) then
        return;
    end

    if (token =="[XP]") then
        if (tValues.default.exp.curr == 55999 or ((player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) and player:GetMainJobLevel() >= 75)) then
            local limString = (TemplateRatio):format("LP", SeparateNumbers(tValues.default.limit.curr, sep), SeparateNumbers(10000, sep));
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(limString);
            end
            compactBar.textObjs[i]:SetText(limString);
        else
            local xpString = (TemplateRatio):format("XP", SeparateNumbers(tValues.default.exp.curr, sep), SeparateNumbers(tValues.default.exp.max, sep));
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(xpString);
            end
            compactBar.textObjs[i]:SetText(xpString);
        end
    elseif (token:find("Bar]")) then
        local totalBars = math.floor((points.settings.compact.font.font_height - 5) * scaling.scale_w(4));
        local strBar = "";

        if (token == "[XPBar]") then
            local xpRatio = 1;
            if (tValues.default.exp.curr == 55999 or ((player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) and player:GetMainJobLevel() >= 75)) then
                xpRatio = math.floor(totalBars * (tValues.default.limit.curr / 10000))
            else
                xpRatio = math.floor(totalBars * (tValues.default.exp.curr / tValues.default.exp.max))
            end
            local fill = totalBars - xpRatio;
            local strProgress = "";
            local strFill = "";
            
            for i=1,xpRatio do
                strProgress = strProgress .. "|";
            end
            strProgress = EncodeColor(strProgress, T{ 0.89, 0.45, 0.46, 1.0 });

            for i=1,fill do
                strFill = strFill .. "|";
            end
            strFill = EncodeColor(strFill, T{ 1.0, 1.0, 1.0, 0.33 });
            strBar = strProgress .. strFill;
        end
        compactBar.textObjs[i]:SetText(strBar);
    elseif (token =="[Merits]" and jobLevel >= 75) then
        if (tValues.default.limit.points == tValues.default.limit.maxpoints) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.TextColored(points.settings.colors.cappedValue, string.format("[%d]", tValues.default.limit.points));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, EncodeColor(tValues.default.limit.points, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format("[%d]", tValues.default.limit.points));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, tValues.default.limit.points));
        end
    elseif (token =="[XPHour]") then
        if (tValues.default.exp.curr == 55999 or ((player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) and player:GetMainJobLevel() >= 75)) then
            local ratioVal = tValues.default.estMpHour;
            local dispLabel = "MP";
            if (not points.settings.show_lphr[1]) then
                ratioVal = tValues.default.estXpHour;
                dispLabel = "LP";
            end
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format("(%s %s/hr)", SeparateNumbers(AbbreviateNum(ratioVal), sep), dispLabel));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(ratioVal), dispLabel));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format("(%s XP/hr)", SeparateNumbers(AbbreviateNum(tValues.default.estXpHour), sep)));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(tValues.default.estXpHour), "XP"));
        end
    elseif (token =="[XPChain]") then
        local label = "XP";
        if (player:GetExpCurrent() == 55999 or ((player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) and player:GetMainJobLevel() >= 75)) then
            label = "LP";
        end
        if (tValues.default.xpTimer > 0) then
            local xpTimeMin = math.floor(tValues.default.xpTimer / 60);
            local xpTimeSec = tValues.default.xpTimer % 60;
            local timeString = "";
            if (xpTimeMin > 0) then
                timeString = ("%dm %ds"):format(xpTimeMin, xpTimeSec);
            else
                timeString = ("%ds"):format(xpTimeSec);
            end
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.chainTimer, string.format("%d (%s)", tValues.default.xpChain, timeString));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, EncodeColor(tValues.default.xpChain, points.settings.colors.chainTimer), EncodeColor(timeString, points.settings.colors.chainTimer)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.xpChain, 0));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, tValues.default.xpChain, "0s"));
        end
    elseif (token =="[CP]" and jobLevel >= 99) then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format("CP: %s/%s", SeparateNumbers(tValues.default.capacity.curr, sep), SeparateNumbers(30000, sep)));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRatio, "CP", SeparateNumbers(tValues.default.capacity.curr, sep), SeparateNumbers(30000, sep)));
    elseif (token =="[JP]" and jobLevel >= 99) then
        if (tValues.default.capacity.points >= 500) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.TextColored(points.settings.colors.cappedValue, string.format("[%d]", tValues.default.capacity.points));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, EncodeColor(tValues.default.capacity.points, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format("[%d]", tValues.default.capacity.points));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, tValues.default.capacity.points));
        end
    elseif (token =="[JPHour]" and jobLevel >= 99) then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format("(%.1f JP/hr)", tValues.default.estJpHour));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRate, tValues.default.estJpHour, "JP"));
    elseif (token =="[CPChain]" and jobLevel >= 99) then        
        if (tValues.default.cpTimer > 0) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("CP\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.chainTimer, string.format("%d (%ds)", tValues.default.cpChain, tValues.default.cpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, "CP", EncodeColor(tValues.default.cpChain, points.settings.colors.chainTimer), EncodeColor(tValues.default.cpTimer, points.settings.colors.chainTimer)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("CP\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.cpChain, tValues.default.cpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, "CP", tValues.default.cpChain, tValues.default.cpTimer));
        end
    elseif (token == "[EP]" and tValues.default.mBreaker) then
        local numString = ("%s/%s"):format(SeparateNumbers(tValues.default.mastery.curr, sep), SeparateNumbers(tValues.default.mastery.max, sep));
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format("EP: %s", numString));
        end
        compactBar.textObjs[i]:SetText((TemplatePlain):format("EP", numString));
    elseif (token == "[EPHour]" and tValues.default.mBreaker) then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format("(%s EP/hr)", SeparateNumbers(AbbreviateNum(tValues.default.estEpHour), sep)));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(tValues.default.estEpHour), "EP"));
    elseif (token == "[EPChain]" and tValues.default.mBreaker) then
        local label = "EP";
        if (tValues.default.epTimer > 0) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.chainTimer, string.format("%d (%ds)", tValues.default.epChain, tValues.default.epTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, EncodeColor(tValues.default.epChain, points.settings.colors.chainTimer), EncodeColor(tValues.default.epTimer, points.settings.colors.chainTimer)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then                
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.epChain, tValues.default.epTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, tValues.default.epChain, tValues.default.epTimer));
        end
    elseif (token =="[Sparks]") then
        if (tValues.default.sparks == 99999) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("\xef\x83\xa7:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, string.format("%d ", tValues.default.sparks));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Spk", EncodeColor(SeparateNumbers(tValues.default.sparks, sep), points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("\xef\x83\xa7:");
                imgui.SameLine();
                imgui.Text(string.format("%s", SeparateNumbers(tValues.default.sparks, sep)));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Spk", SeparateNumbers(tValues.default.sparks, sep)));
        end
    elseif (token =="[Accolades]") then
        if (tValues.default.accolades == 99999) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("\xef\x96\xa2:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, string.format("%d ", tValues.default.accolades));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Acc", EncodeColor(SeparateNumbers(tValues.default.accolades, sep), points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("\xef\x96\xa2:");
                imgui.SameLine();
                imgui.Text(string.format("%s", SeparateNumbers(tValues.default.accolades, sep)));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Acc", SeparateNumbers(tValues.default.accolades, sep)));
        end
    elseif (token =="[DynamisKI]") then
        local outCompact = "";
        for i,v in pairs(tValues.dynamis.keyItems) do
            if (i > 1 and (not points.settings.use_compact_ui[1] or points.use_both)) then
                imgui.SameLine();
            end;

            if (v) then
                if (not points.settings.use_compact_ui[1] or points.use_both) then
                    imgui.Text("\xef\x89\x92");
                end
                outCompact = outCompact .. "O";
            else
                if (not points.settings.use_compact_ui[1] or points.use_both) then
                    imgui.TextColored(DefaultColors.FFXILightGrey, "\xef\x89\x94");
                end
                outCompact = outCompact .. EncodeColor("X", DefaultColors.FFXILightGrey);
            end

            if (i < 5) then
                outCompact = outCompact .. " ";
            end
        end       

        compactBar.textObjs[i]:SetText(outCompact);
    elseif (token =="[Pearl]") then
        if (tValues.abyssea.pearlescent >= 230) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Pearl:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.pearlescent));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Pearl", EncodeColor(tValues.abyssea.pearlescent, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Pearl:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.pearlescent));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Pearl", tValues.abyssea.pearlescent));
        end;
    elseif (token =="[Azure]") then
        if (tValues.abyssea.azure >= 255) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Azure:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.azure));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Azure", EncodeColor(tValues.abyssea.azure, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Azure:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.azure));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Azure", tValues.abyssea.azure));
        end;
    elseif (token =="[Ruby]") then
        if (tValues.abyssea.ruby >= 255) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Ruby:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.ruby));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ruby", EncodeColor(tValues.abyssea.ruby, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Ruby:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.ruby));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ruby", tValues.abyssea.ruby));
        end;
    elseif (token =="[Amber]") then
        if (tValues.abyssea.amber >= 255) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Amber:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.amber));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Amber", EncodeColor(tValues.abyssea.amber, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Amber:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.amber));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Amber", tValues.abyssea.amber));
        end;
    elseif (token =="[Gold]") then
        if (tValues.abyssea.golden >= 200) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Gold:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.golden));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Gold", EncodeColor(tValues.abyssea.golden, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Gold:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.golden));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Gold", tValues.abyssea.golden));
        end;
    elseif (token =="[Silver]") then
        if (tValues.abyssea.silvery >= 200) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Silver:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.silvery));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Silver", EncodeColor(tValues.abyssea.silvery, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Silver:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.silvery));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Silver", tValues.abyssea.silvery));
        end;
    elseif (token =="[Ebon]") then
        if (tValues.abyssea.ebon >= 200) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Ebon:");
                imgui.SameLine();
                imgui.TextColored(points.settings.colors.cappedValue, tostring(tValues.abyssea.ebon));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ebon", EncodeColor(tValues.abyssea.ebon, points.settings.colors.cappedValue)));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text("Ebon:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.ebon));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ebon", tValues.abyssea.ebon));
        end;
    elseif (token == "[AssaultObjective]") then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(tValues.assault.objective);
        end
        compactBar.textObjs[i]:SetText(tValues.assault.objective);
    elseif (token == "[NyzulObjective]") then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(tValues.nyzul.objective);
        end
        compactBar.textObjs[i]:SetText(tValues.nyzul.objective);
    elseif (token =="[NyzulFloor]") then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text("Floor: " .. tostring(tValues.nyzul.floor));
        end
        compactBar.textObjs[i]:SetText("Floor: " .. tostring(tValues.nyzul.floor));
    elseif (token == "[EventTimer]") then
        local extractedTime = GetHMS(tValues.eventTimer);
        if (tValues.eventTimer <= 60) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.TextColored(DefaultColors.FFXICrimson, string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(EncodeColor(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec), DefaultColors.FFXICrimson));
        elseif (tValues.eventTimer <= 300) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.TextColored(DefaultColors.FFXIAmber, string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(EncodeColor(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec), DefaultColors.FFXIYellow));
        else
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
        end
    elseif (token == "[Gil]") then
        local gil = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0);
        if (gil) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text(string.format("%s G", SeparateNumbers(gil.Count, sep)));
            end
            compactBar.textObjs[i]:SetText(string.format("%s G", SeparateNumbers(gil.Count, sep)));
        end
    elseif (token == "[Inv]") then
        local inv =  AshitaCore:GetMemoryManager():GetInventory();
        local max = inv:GetContainerCountMax(0);
        local cnt = inv:GetContainerCount(0);
        if (max > 0) then
            if (not points.settings.use_compact_ui[1] or points.use_both) then
                imgui.Text((TemplateRatio):format("\xef\x8a\x90", SeparateNumbers(cnt, sep), SeparateNumbers(max, sep)));
            end
            compactBar.textObjs[i]:SetText((TemplateRatio):format("Inv", SeparateNumbers(cnt, sep), SeparateNumbers(max, sep)));
        end
    elseif (token == "[TNL]") then
        local tnl = tValues.default.exp.max - tValues.default.exp.curr;
        if (tValues.default.exp.curr == 55999 or ((player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) and player:GetMainJobLevel() >= 75)) then
           tnl = 10000 - tValues.default.limit.curr;
        end
        
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format("TNL: %s", SeparateNumbers(tnl, sep)));
        end
        compactBar.textObjs[i]:SetText(string.format("TNL: %s", SeparateNumbers(tnl, sep)));
    elseif (token == "[ZoneTimer]") then
        local extractedTime = GetHMS(os.clock() - tValues.zoneTimer);
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.Text(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
    elseif (token:contains("[DIV]")) then
        if (not points.settings.use_compact_ui[1] or points.use_both) then
            imgui.TextColored(DefaultColors.FFXIDarkGrey, points.settings.bar_divider);
        end
        compactBar.textObjs[i]:SetText(EncodeColor(points.settings.compact_divider, DefaultColors.FFXIDarkGrey));
    else
        compactBar.textObjs[i]:SetText("");
    end
end

function InitPointsBar()
    local playerEntity = GetPlayerEntity();
    lastZone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    InitTrackedValues();
    UpdateTokenList(lastZone, true);
    lastJob = player:GetMainJob();
    globalTimer = math.floor(os.clock());

    -- Defaults for compact bar
    LoadCompactBar();

    points.window_suffix = "_" .. playerEntity.Name;
    points.loaded = true;
end

function ReloadImages(theme)
    guiimages = {};
    guiimages = images.loadTextures(theme);
    compactBar.jobicon.background:SetTextureFromFile(string.format("%s/themes/%s/ffxi-jobicons-compact.png", addon.path, theme));
    compactBar.jobicon.background.width = 64;
    compactBar.jobicon.background.height = 16;
    compactBar.jobicon.background.scale_x = scaling.scaled.w;
    compactBar.jobicon.background.scale_y = scaling.scaled.h;
end