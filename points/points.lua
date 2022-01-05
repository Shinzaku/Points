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
addon.version   = "1.0.5";
addon.desc      = "Various resource point and event tracking; Includes XP, CP, Abyssea lights, Dynamis KI and time, Assault objectives and time, Nyzul Isle floor and time";
addon.link      = "https://github.com/Shinzaku/Ashita4-Addons/points";

require "common";
require "globals";
local images = require("images");
local ffi = require("ffi");
local imgui = require("imgui");
local fonts = require("fonts");
local settings = require("settings");

local player = AshitaCore:GetMemoryManager():GetPlayer();
local lastJob = 0;
local lastZone = 0;
local points = T{
    loaded = false,
    bar_is_open = true,
    config_is_open = false,
    window_suffix = "",
    use_both = false,
    settings = settings.load(DefaultSettings)
}
local guiimages = images.loadTextures(points.settings.theme);
local currTokens = {};
local globalTimer = 0;
local tValues = {};
tValues.eventTimer = 0;
tValues.default = { lastXpKillTime = 0, xpKills = {}, xpChain = 0, estXpHour = 0, estMpHour = 0, xpTimer = 0, lastCpKillTime = 0, cpKills = {}, 
                    cpChain = 0, estCpHour = 0, estJpHour = 0, cpTimer = 0, sparks = 0, accolades = 0,
                    mBreaker = false, lastEpKillTime = 0, epKills = {}, epChain = 0, estEpHour = 0, epTimer = 0, };
tValues.dynamis = { keyItems = { false, false, false, false, false } };
tValues.abyssea = { pearlescent = 0, azure = 0, ruby = 0, amber = 0, golden = 0, silvery = 0, ebon = 0, };
tValues.assault = { objective = "", timer = 0, };
tValues.nyzul = { floor = 0, objective = "", };
tValues.voidwatch = { red = 0, blue = 0, green = 0, yellow = 0, white = 0, };

local compactBar = {};
compactBar.wrapper = fonts.new(WrapperSettings);
compactBar.wrapperIndent = "                  ";
compactBar.jobicon = fonts.new(JobIconSettings);
compactBar.jobiconIndent = "   ";
compactBar.textObjs = {};

local debugText = "";

function UpdateSettings(s)
    -- Update the settings table..
    if (s ~= nil) then
        points.settings = s;
    end

    -- Apply the font settings..
    for i,v in pairs(compactBar.textObjs) do
        v:apply(points.settings.compact.font);
    end

    -- Save the current settings..
    settings.save();
end;

settings.register('settings', 'settings_update', UpdateSettings);

----------------------------------------------------------------------------------------------------
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
    compactBar.wrapper:destroy();
    compactBar.jobicon:destroy();
    for i,v in pairs(compactBar.textObjs) do
        v:destroy();
    end
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
            points.config_is_open = not points.config_is_open;
        elseif (args[2] == "compact") then
            points.settings.use_compact = not points.settings.use_compact;
            if (not points.use_both) then
                SetCompactVisibility(points.settings.use_compact);
            end;
            if (points.settings.use_compact) then
                PrintMsg("Displaying compact bar");
            else
                PrintMsg("Reverting to default bar");
            end
        elseif (args[2] == "fsize") then
            local newSize = tonumber(args[3]);
            if (newSize ~= nil) then
                points.settings.compact.font.font_height = newSize;
                for i,v in pairs(compactBar.textObjs) do
                    v.font_height = newSize;
                end
                PrintMsg("Updating font size");
            else
                PrintMsg("Invalid font size");
            end;            
        elseif (args[2] == "ffamily") then
            table.remove(args, 1);
            table.remove(args, 1);
            local newFamily = table.concat(args, " ");
            points.settings.compact.font.font_family = newFamily;
            for i,v in pairs(compactBar.textObjs) do
                v.font_family = newFamily;
            end
            PrintMsg("Attempting to update font family");
        elseif (args[2] == "theme") then
            table.remove(args, 1);
            table.remove(args, 1);
            local newTheme = table.concat(args, "-");
            if (ashita.fs.exists(addon.path .. "/themes/" .. newTheme)) then
                points.settings.theme = newTheme;
                PrintMsg("Changed theme folder to: " .. newTheme);
            else
                PrintMsg("Unable to find requested theme folder");
            end;
        elseif (args[2] == "bgcolor") then
            local r, g, b, a;
            if (args[3] == "default") then
                r = DefaultColors.FFXIGreyBg[1] * 255;
                g = DefaultColors.FFXIGreyBg[2] * 255;
                b = DefaultColors.FFXIGreyBg[3] * 255;
                a = DefaultColors.FFXIGreyBg[4] * 255;
            else
                r = tonumber(args[3]);
                g = tonumber(args[4]);
                b = tonumber(args[5]);
                a = tonumber(args[6]);
            end;
            
            if (r == nil or g == nil or b == nil or a  == nil) then
                PrintMsg("Invalid values for color");
            else
                points.settings.bg_color = { (r / 255), (g / 255), (b / 255), (a / 255) };
                compactBar.wrapper.background.color = RGBAtoHex(points.settings.bg_color);
                PrintMsg("Background color changed");
            end
        elseif (args[2] == "border") then
            local r, g, b, a;
            if (args[3] == "default") then
                r = DefaultColors.FFXIGreyBorder[1] * 255;
                g = DefaultColors.FFXIGreyBorder[2] * 255;
                b = DefaultColors.FFXIGreyBorder[3] * 255;
                a = DefaultColors.FFXIGreyBorder[4] * 255;
            else
                r = tonumber(args[3]);
                g = tonumber(args[4]);
                b = tonumber(args[5]);
                a = tonumber(args[6]);
            end;

            if (r == nil or g == nil or b == nil or a  == nil) then
                PrintMsg("Invalid values for color");
            else
                points.settings.bg_border_color = { r / 255, g / 255, b / 255, a / 255 };
                compactBar.wrapper.background.border_color = RGBAtoHex(points.settings.bg_border_color);
                PrintMsg("Border color changed");
            end
        elseif (args[2] == "defaults") then
            points.settings.token_order_default = DefaultSettings.token_order_default;
            points.settings.token_order_mastered = DefaultSettings.token_order_mastered;
            local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
            UpdateFromZone(zone, false);
        elseif (args[2] == "bothbars") then
            points.use_both = not points.use_both;
            SetCompactVisibility(points.settings.use_compact);
            if (points.use_both) then                
                PrintMsg("Displaying both bars for testing purposes");
            else
                PrintMsg("Reverting to single bar mode");
            end
        elseif (args[2] == "cleardebug") then
            PrintMsg("Clearing debug text");
            debugText = "";
        elseif (args[2] == nil or args[2] == "help") then
            PrintMsg("Help and available commands:\n" .. HelpString);
        end

        return;
    end
end);

----------------------------------------------------------------------------------------------------
-- func: packet_out
-- desc: Event called when the addon is processing outgoing packets.
----------------------------------------------------------------------------------------------------
ashita.events.register('packet_out', 'packet_out_callback1', function (e)
    --[[ Valid Arguments

        e.id                 - (ReadOnly) The id of the packet.
        e.size               - (ReadOnly) The size of the packet.
        e.data               - (ReadOnly) The data of the packet.
        e.data_raw           - The raw data pointer of the packet. (Use with FFI.)
        e.data_modified      - The modified data.
        e.data_modified_raw  - The modified raw data. (Use with FFI.)
        e.chunk_size         - The size of the full packet chunk that contained the packet.
        e.chunk_data         - The data of the full packet chunk that contained the packet.
        e.chunk_data_raw     - The raw data pointer of the full packet chunk that contained the packet. (Use with FFI.)
        e.injected           - (ReadOnly) Flag that states if the packet was injected by Ashita or an addon/plugin.
        e.blocked            - Flag that states if the packet has been, or should be, blocked.
    --]]

    -- Look for emote packets..
    if (e.id == 0x100) then
        -- Job change update
        local jobId = struct.unpack("B", e.data, 0x05);
        local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        UpdateFromZone(zone, true, jobId);
    end
end);

----------------------------------------------------------------------------------------------------
-- func: packet_in
-- desc: Event called when the addon is processing incoming packets.
----------------------------------------------------------------------------------------------------
ashita.events.register("packet_in", "packet_in_callback1", function (e)
    if (e.id == 0x02D) then
        local val = struct.unpack("I", e.data, 0x11);
        local val2 = struct.unpack("I", e.data, 0x15);
		local msgId = struct.unpack("H", e.data, 0x19) % 1024;
        
        local killTime = os.clock();
        if (msgId == 718 or msgId == 735) then
            if (tValues.default.lastCpKillTime ~= 0) then
                table.insert(tValues.default.cpKills, { time=(killTime - tValues.default.lastCpKillTime), cp=val});   
            else
                table.insert(tValues.default.cpKills, { time=1, cp=val});   
            end
            tValues.default.cpChain = val2;
            tValues.default.cpTimer = 30;
            tValues.default.lastCpKillTime = killTime;
        elseif (msgId == 8 or msgId == 105 or msgId == 371 or msgId == 372) then
            if (tValues.default.lastXpKillTime ~= 0) then
                table.insert(tValues.default.xpKills, { time=(killTime - tValues.default.lastXpKillTime), xp=val});   
            else
                table.insert(tValues.default.xpKills, { time=1, xp=val});   
            end
            tValues.default.xpChain = val2;
            tValues.default.xpTimer = 60;        
            tValues.default.lastXpKillTime = killTime;
        elseif (msgId == 809 or msgId == 810) then
            if (tValues.default.lastEpKillTime ~= 0) then
                table.insert(tValues.default.epKills, { time=(killTime - tValues.default.lastEpKillTime), ep=val});   
            else
                table.insert(tValues.default.epKills, { time=1, ep=val});   
            end
            tValues.default.epChain = val2;
            tValues.default.epTimer = 30;        
            tValues.default.lastEpKillTime = killTime;
        end
    elseif (e.id == 0x061) then
        -- char stats
    elseif (e.id == 0x110) then
        tValues.default.sparks = struct.unpack("I", e.data, 0x05);
	elseif (e.id == 0x113) then
        tValues.default.sparks = struct.unpack("I", e.data, 0x75);
		tValues.default.accolades = struct.unpack('I', e.data, 0xE5);
    elseif (e.id == 0x00A) then	
		local zoneId = struct.unpack('H', e.data, 0x30 + 1);
		if (zoneId == 0) then
			zoneId = struct.unpack('H', e.data, 0x42 + 1);
		end
        
        if (points.loaded) then
            UpdateFromZone(zoneId, true);
        end				
    elseif (e.id == 0x055) then
        --print("KI Log Update");
        local type = struct.unpack("B", e.data, 0x85);
        --debugText = debugText .. "Key Item Packet (Type " .. type ..")\n";
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
    elseif (e.id == 0x029) then
        --print("Action message");
    elseif (e.id == 0x02A) then
        --print("Resting message");
        local pId = struct.unpack("I", e.data, 0x05);
        local p1 = struct.unpack("I", e.data, 0x09);
        local p2 = struct.unpack("I", e.data, 0x0D);
        local p3 = struct.unpack("I", e.data, 0x11);
        local p4 = struct.unpack("I", e.data, 0x15);
        local pIx = struct.unpack("H", e.data, 0x19);
        local mId = struct.unpack("H", e.data, 0x1B); -- % 2 ^ 14;
        local rMsgId = mId % 2 ^ 14;
        local unk = struct.unpack("I", e.data, 0x1D);
        --print(string.format("ID: %d(%d), Size: %d (%d, %d, %d, %d), Pid: %d, Pix: %d, unk: %d", mId, rMsgId, e.size, p1, p2, p3, p4, pId, pIx, unk));
    elseif (e.id == 0x036) then
        --print("NPC Dialogue");
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
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AbysseaRestLights2);
            if (results ~= nil) then
                tValues.abyssea.golden = tonumber(results[1][2]);
                tValues.abyssea.silvery = tonumber(results[1][3]);
                return;
            end
            results = ashita.regex.search(e.message, MessageMatch.AbysseaRestLights3);
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
        elseif (AssaultMapping[lastZone] ~= nil) then
            results = ashita.regex.search(e.message, MessageMatch.AssaultObj);
            if (results ~= nil) then
                tValues.assault.objective = results[1][2] .. " -> " .. string.sub(results[1][4], 1, string.len(results[1][4] - 1));
                return;
            end
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
    end;

    local currJob = player:GetMainJob();
    local currZone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    if (player.isZoning or currJob == 0) then        
        if (compactBar.wrapper:GetVisible()) then
            SetCompactVisibility(false);
        end
        return;    
    elseif ((points.settings.use_compact and not compactBar.wrapper:GetVisible()) or points.use_both) then
        SetCompactVisibility(true);
        return;
    elseif (not points.settings.use_compact and compactBar.textObjs[1]:GetVisible() and not points.use_both) then
        SetCompactVisibility(false);
        return;
    elseif (currZone ~= nil and currZone ~= 0 and currZone ~= lastZone) then
        lastZone = currZone;
    end
    if (currJob ~= lastJob) then
        lastJob = currJob;
    end
    -----------------------------
    -- Recalculate estimations --
    -----------------------------
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
    DrawConfigWindow();    
end);

function DrawPointsBar(currJob)
    local jobLevel = player:GetMainJobLevel();
    if (tValues.default.mBreaker) then
        jobLevel = player:GetMasteryJobLevel();
    end
    if (not points.settings.use_compact or points.use_both) then
        imgui.SetNextWindowSize({ -1, 32 }, ImGuiCond_Always);
        imgui.SetNextWindowPos({ points.settings.bar_x, points.settings.bar_y }, ImGuiCond_FirstUseEver);    
    end    
    imgui.PushStyleColor(ImGuiCol_WindowBg, points.settings.bg_color);
    imgui.PushStyleColor(ImGuiCol_Border, points.settings.bg_border_color);
    imgui.PushStyleColor(ImGuiCol_BorderShadow, { 1.0, 0.0, 0.0, 1.0});
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    if((not points.settings.use_compact or points.use_both) and imgui.Begin("PointsBar" .. points.window_suffix, points.bar_is_open, bit.bor(ImGuiWindowFlags_NoDecoration))) then        
        imgui.PopStyleColor(3);
        -----------------------------------------
        -- Left image icon, with job and level --
        -----------------------------------------
        local imgOffsetX = (1.0 / (384 / 64)) * math.fmod(currJob - 1.0, 6.0);
        local imgOffsetY = 0.25 * math.floor((currJob - 1) / 6.0);
        local imgOffsetX2 = imgOffsetX + (1.0 / (384 / 64.0));
        local imgOffsetY2 = imgOffsetY + 0.25;
        imgui.Image(tonumber(ffi.cast("uint32_t", guiimages.jobicons)), { 64, 32 }, { imgOffsetX, imgOffsetY }, { imgOffsetX2, imgOffsetY2 }, { 1, 1, 1, 1 }, { 1, 1, 1, 0 });
        imgui.SetCursorPos({ 43, 0 });
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 5 });
        imgui.AlignTextToFramePadding();
        imgui.Text(string.format("%02d", jobLevel));
        imgui.PopStyleVar(1);
        imgui.SameLine();
        imgui.SetCursorPos({ 72, 0 });
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 10 });
        imgui.AlignTextToFramePadding();

        --------------------
        --- Main text bar --
        --------------------        
        imgui.SetWindowFontScale(points.settings.font_scale);
        for i,v in pairs(currTokens) do
            if (i > 1) then
                imgui.SameLine();
            end
    
            ParseToken(i, v);
            
            if (i == 1) then
                imgui.PopStyleVar(1);
            end
        end
    
        imgui.SameLine();
        imgui.Text(" ");        
        imgui.End();
    else
        imgui.PopStyleColor(3);
    end
    imgui.PopStyleVar(1);
end

function LoadCompactBar()
    compactBar.wrapper.auto_resize = false;
    compactBar.wrapper.background.visible = true;
    compactBar.wrapper.background.color = RGBAtoHex(points.settings.bg_color);
    compactBar.wrapper.background.border_flags = 15;
    compactBar.wrapper.background.border_color = RGBAtoHex(points.settings.bg_border_color);
    local bSizes = RECT.new();
    bSizes.top = 1.0;
    bSizes.left = 1.0;
    bSizes.right = 1.0;
    bSizes.bottom = 1.0;
    compactBar.wrapper.background.border_sizes = bSizes;    
    compactBar.wrapper.background.border_visible = true;
    compactBar.wrapper.lockedz = true;  
    compactBar.wrapper.position_x = points.settings.compact.x;
    compactBar.wrapper.position_y = points.settings.compact.y;
    compactBar.wrapper.visible = points.settings.use_compact;

    compactBar.jobicon.auto_resize = false;
    compactBar.jobicon.can_focus = false;
    compactBar.jobicon.font_height = 10;
    compactBar.jobicon.font_family = "Consolas";
    compactBar.jobicon.color_outline = 0xFF000000;
    compactBar.jobicon.background.visible = true;
    compactBar.jobicon.background:SetTextureFromFile(string.format("%s/themes/%s/ffxi-jobicons-compact.png", addon.path, points.settings.theme));    
    compactBar.jobicon.background.width = 64;
    compactBar.jobicon.background.height = 16;
    compactBar.jobicon.visible = points.settings.use_compact;
    compactBar.jobicon.parent = compactBar.wrapper;

    -- Default bar items --
    for i=1,#currTokens,1 do
        compactBar.textObjs[i] = fonts.new(points.settings.compact.font);
        compactBar.textObjs[i].can_focus = false;
        compactBar.textObjs[i].parent = compactBar.wrapper;
        compactBar.textObjs[i].visible = points.settings.use_compact;
    end
end

function UpdateCompactBar(currJob)
    local totalSize = SIZE.new();
    totalSize.cx = 64 + points.settings.compact.hPadding;
    totalSize.cy = 16;

    if (#compactBar.textObjs > #currTokens) then
        for i=#currTokens + 1,#compactBar.textObjs,1 do
            compactBar.textObjs[i]:destroy();
            compactBar.textObjs[i] = nil;
        end
    elseif (#compactBar.textObjs < #currTokens) then
        for i=#compactBar.textObjs + 1,#currTokens,1 do
            compactBar.textObjs[i] = fonts.new(points.settings.compact.font);
            compactBar.textObjs[i].can_focus = false;
            compactBar.textObjs[i].visible = points.settings.use_compact;
            compactBar.textObjs[i].parent = compactBar.wrapper;
        end
    end

    ------------------------------------------
    -- Job Icon display
    ------------------------------------------
    local imgOffsetX = 64 * math.fmod(currJob - 1.0, 6.0);
    local imgOffsetY = 17 * math.floor((currJob - 1) / 6.0);
    compactBar.jobicon.background.texture_offset_x = imgOffsetX;
    compactBar.jobicon.background.texture_offset_y = imgOffsetY;
    local jobLevel = player:GetMainJobLevel();
    if (tValues.default.mBreaker) then
        jobLevel = player:GetMasteryJobLevel();
    end
    compactBar.jobicon.text = compactBar.jobiconIndent .. string.format("%02d", jobLevel);
    -------------------------------------------
    -- These values are already being calculated while default bar is displayed; Ensures the tokens are parsed otherwise --
    if (points.settings.use_compact and not points.use_both) then
        for i,v in pairs(currTokens) do
            ParseToken(i, v);
        end
    end
    -------------------------------------------
    local lastSize = SIZE.new();
    for i,v in pairs(compactBar.textObjs) do
        v:GetTextSize(lastSize);
        if (i > 1 and v.text ~= "") then
            v.position_x = totalSize.cx + points.settings.compact.hPadding;
            totalSize.cx = totalSize.cx + lastSize.cx + points.settings.compact.hPadding;
        elseif (v.text ~= "") then
            v.position_x = totalSize.cx;
            totalSize.cx = totalSize.cx + lastSize.cx;
        end;
        totalSize.cy = lastSize.cy;
    end
    compactBar.wrapper.background.width = totalSize.cx + points.settings.compact.hPadding;
    if (points.settings.compact.font.font_height > 11) then
        compactBar.wrapper.background.height = totalSize.cy;
    else
        compactBar.wrapper.background.height = 16;
    end;

    points.settings.compact.x = compactBar.wrapper.position_x;
    points.settings.compact.y = compactBar.wrapper.position_y;
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
    tValues.default.mBreaker = player:HasKeyItem(GetKeyItemFromName("master breaker"));
    tValues.default.sparks = 0;
    tValues.default.accolades = player:GetUnityPoints();
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

function UpdateFromZone(zoneId, reset, jobId)
    if (DynamisMapping[zoneId] ~= nil) then
        currTokens = ashita.regex.split(points.settings.token_order_dynamis, " ");
        if (reset) then
            tValues.eventTimer = 3600;
        end
    elseif (AbysseaMapping[zoneId] ~= nil) then
        currTokens = ashita.regex.split(points.settings.token_order_abyssea, " ");
        if (reset) then
            for i,v in pairs(tValues.abyssea) do
                v = 0;
            end
            tValues.eventTimer = 300;
        end
    elseif (AssaultMapping[zoneId] ~= nil) then
        currTokens = ashita.regex.split(points.settings.token_order_assault, " ");
        if (reset) then
            tValues.eventTimer = 1800;
        end
    elseif (NyzulMapping[zoneId] ~= nil) then
        currTokens = ashita.regex.split(points.settings.token_order_nyzul, " ");
    else         
        local currJob = player:GetMainJob();
        local mastered = player:GetJobPointsSpent(currJob) == 2100;
        if (jobId) then
            mastered = player:GetJobPointsSpent(jobId) == 2100;
        end
        if (tValues.default.mBreaker and mastered) then
            currTokens = ashita.regex.split(points.settings.token_order_mastered, " ");
        else
            currTokens = ashita.regex.split(points.settings.token_order_default, " ");
        end
        if (reset) then
            for i,v in pairs(tValues.dynamis.keyItems) do
                v = false;
            end
            tValues.eventTimer = 0;
        end
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

function GetKeyItemFromName(name)
    local findKI = AshitaCore:GetResourceManager():GetString("keyitems.names", name, 2);
    if (findKI ~= nil) then
        return findKI;
    end
    return -1;
end

function GetHMS(seconds)
    local timeExtract = {
        hr = 0,
        min = 0,
        sec = 0,
    };
    if (seconds > 0) then
        timeExtract.hr = seconds / 3600;
        timeExtract.min = (math.fmod(seconds, 3600)) / 60;
        timeExtract.sec = math.fmod(math.fmod(seconds, 3600), 60);
    end

    return timeExtract;
end

function AbbreviateNum(val)
    local abbreviated = "";
    if (val >= 100000 and val < 1000000) then
        abbreviated = string.format("%.1fK", val / 1000);
    elseif (val >= 1000000) then
        abbreviated = string.format("%.1fM", val / 1000000);
    else
        abbreviated = string.format("%d", val);
    end

    return abbreviated;
end

function SeparateNumbers(val)
    local separated = string.gsub(val, "(%d)(%d%d%d)$", "%1" .. points.settings.num_separator .. "%2", 1)
    local found = 0;
    while true do
        separated, found = string.gsub(separated, "(%d)(%d%d%d),", "%1" .. points.settings.num_separator .. "%2,", 1)
        if found == 0 then break end
    end
    return separated;
end

function RGBAtoHex(colorTable)
    local r, g, b, a;
    r = string.format("%02X", math.floor(255 * colorTable[1]));
    g = string.format("%02X", math.floor(255 * colorTable[2]));
    b = string.format("%02X", math.floor(255 * colorTable[3]));
    a = string.format("%02X", math.floor(255 * colorTable[4]));
	
	local addString = a .. r .. g .. b;
	return tonumber(addString, 16);
end

function EncodeColor(text, rgba)
    return string.format("|c%X|%s|r", RGBAtoHex(rgba), text);
end

function PrintMsg(msg)
    print(string.format("[\30\08Points\30\1] \30\67%s", msg));
end;

function ParseToken(i, token)
    local jobLevel = player:GetMainJobLevel();
    local currJob = player:GetMainJob();

    if (compactBar.textObjs[i] == nil) then
        return;
    end

    if (token =="[XP]") then
        if (player:GetExpCurrent() == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("LP: %s/%s", SeparateNumbers(player:GetLimitPoints()), SeparateNumbers(10000)));    
            end            
            compactBar.textObjs[i]:SetText(string.format(TemplateRatio, "LP", SeparateNumbers(player:GetLimitPoints()), SeparateNumbers(10000)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("XP: %s/%s", SeparateNumbers(player:GetExpCurrent()), SeparateNumbers(player:GetExpNeeded())));    
            end            
            compactBar.textObjs[i]:SetText(string.format(TemplateRatio, "XP", SeparateNumbers(player:GetExpCurrent()), SeparateNumbers(player:GetExpNeeded())));
        end
    elseif (token =="[Merits]" and jobLevel >= 75) then
        if (player:GetMeritPoints() == player:GetMeritPointsMax()) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.TextColored(DefaultColors.FFXICappedValue, string.format("[%d]", player:GetMeritPoints()));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, EncodeColor(player:GetMeritPoints(), DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("[%d]", player:GetMeritPoints()));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, player:GetMeritPoints()));
        end
    elseif (token =="[XPHour]") then
        if (player:GetExpCurrent() == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("(%s LP/hr)", SeparateNumbers(AbbreviateNum(tValues.default.estXpHour))));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(tValues.default.estXpHour), "LP"));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("(%s XP/hr)", SeparateNumbers(AbbreviateNum(tValues.default.estXpHour))));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(tValues.default.estXpHour), "XP"));
        end
    elseif (token =="[XPChain]") then
        local label = "XP";
        if (player:GetExpCurrent() == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked()) then
            label = "LP";
        end
        if (tValues.default.xpTimer > 0) then
            if (not points.settings.use_compact or points.use_both) then                
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(DefaultColors.FFXIYellow, string.format("%d (%ds)", tValues.default.xpChain, tValues.default.xpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, EncodeColor(tValues.default.xpChain, DefaultColors.FFXIYellow), EncodeColor(tValues.default.xpTimer, DefaultColors.FFXIYellow)));
        else
            if (not points.settings.use_compact or points.use_both) then                
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.xpChain, tValues.default.xpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, tValues.default.xpChain, tValues.default.xpTimer));
        end
    elseif (token =="[CP]" and jobLevel >= 99) then
        if (not points.settings.use_compact or points.use_both) then
            imgui.Text(string.format("CP: %s/%s", SeparateNumbers(player:GetCapacityPoints(currJob)), SeparateNumbers(30000)));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRatio, "CP", SeparateNumbers(player:GetCapacityPoints(currJob)), SeparateNumbers(30000)));
    elseif (token =="[JP]" and jobLevel >= 99) then
        local currJobPoints = player:GetJobPoints(currJob);
        if (currJobPoints >= 500) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.TextColored(DefaultColors.FFXICappedValue, string.format("[%d]", currJobPoints));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, EncodeColor(currJobPoints, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format("[%d]", currJobPoints));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateBracket, currJobPoints));
        end
    elseif (token =="[JPHour]" and jobLevel >= 99) then
        if (not points.settings.use_compact or points.use_both) then
            imgui.Text(string.format("(%.1f JP/hr)", tValues.default.estJpHour));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRate, tValues.default.estJpHour, "JP"));
    elseif (token =="[CPChain]" and jobLevel >= 99) then        
        if (tValues.default.cpTimer > 0) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("CP\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(DefaultColors.FFXIYellow, string.format("%d (%ds)", tValues.default.cpChain, tValues.default.cpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, "CP", EncodeColor(tValues.default.cpChain, DefaultColors.FFXIYellow), EncodeColor(tValues.default.cpTimer, DefaultColors.FFXIYellow)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("CP\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.cpChain, tValues.default.cpTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, "CP", tValues.default.cpChain, tValues.default.cpTimer));
        end        
    elseif (token == "[EP]" and tValues.default.mBreaker) then
        if (not points.settings.use_compact or points.use_both) then
            imgui.Text(string.format("EP: %s/%s", SeparateNumbers(player:GetMasteryExp()), SeparateNumbers(player:GetMasteryExpNeeded())));
        end
        compactBar.textObjs[i]:SetText(string.format("EP: %s/%s", SeparateNumbers(player:GetMasteryExp()), SeparateNumbers(player:GetMasteryExpNeeded())));
    elseif (token == "[EPHour]" and tValues.default.mBreaker) then
        if (not points.settings.use_compact or points.use_both) then
            imgui.Text(string.format("(%s EP/hr)", SeparateNumbers(AbbreviateNum(tValues.default.estEpHour))));
        end
        compactBar.textObjs[i]:SetText(string.format(TemplateRateAbbr, AbbreviateNum(tValues.default.estEpHour), "EP"));
    elseif (token == "[EPChain]" and tValues.default.mBreaker) then
        local label = "EP";
        if (tValues.default.epTimer > 0) then
            if (not points.settings.use_compact or points.use_both) then                
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.TextColored(DefaultColors.FFXIYellow, string.format("%d (%ds)", tValues.default.epChain, tValues.default.epTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, EncodeColor(tValues.default.epChain, DefaultColors.FFXIYellow), EncodeColor(tValues.default.epTimer, DefaultColors.FFXIYellow)));
        else
            if (not points.settings.use_compact or points.use_both) then                
                imgui.Text(label .. "\xef\x83\x81>");
                imgui.SameLine();
                imgui.Text(string.format("%d (%ds)", tValues.default.epChain, tValues.default.epTimer));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateChain, label, tValues.default.epChain, tValues.default.epTimer));
        end
    elseif (token =="[Sparks]") then
        if (tValues.default.sparks == 99999) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("\xef\x83\xa7:");
                imgui.SameLine();
                imgui.TextColored(DefaultColors.FFXICappedValue, string.format("%d ", tValues.default.sparks));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Spk", EncodeColor(SeparateNumbers(tValues.default.sparks), DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("\xef\x83\xa7:");
                imgui.SameLine();
                imgui.Text(string.format("%s", SeparateNumbers(tValues.default.sparks)));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Spk", SeparateNumbers(tValues.default.sparks)));
        end
    elseif (token =="[Accolades]") then        
        if (tValues.default.accolades == 99999) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("\xef\x96\xa2:");
                imgui.SameLine();
                imgui.TextColored(DefaultColors.FFXICappedValue, string.format("%d ", tValues.default.accolades));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Acc", EncodeColor(SeparateNumbers(tValues.default.accolades), DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("\xef\x96\xa2:");
                imgui.SameLine();
                imgui.Text(string.format("%s", SeparateNumbers(tValues.default.accolades)));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Acc", SeparateNumbers(tValues.default.accolades)));
        end
    elseif (token =="[DynamisKI]") then
        local outCompact = "";
        for i,v in pairs(tValues.dynamis.keyItems) do
            if (i > 1 and (not points.settings.use_compact or points.use_both)) then
                imgui.SameLine();
            end;

            if (v) then
                if (not points.settings.use_compact or points.use_both) then
                    imgui.Text("\xef\x89\x92");
                end
                outCompact = outCompact .. "O";
            else
                if (not points.settings.use_compact or points.use_both) then
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
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Pearl:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.pearlescent, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Pearl", EncodeColor(tValues.abyssea.pearlescent, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Pearl:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.pearlescent));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Pearl", tValues.abyssea.pearlescent));
        end;
    elseif (token =="[Azure]") then
        if (tValues.abyssea.azure >= 255) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Azure:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.azure, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Azure", EncodeColor(tValues.abyssea.azure, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Azure:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.azure));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Azure", tValues.abyssea.azure));
        end;
    elseif (token =="[Ruby]") then
        if (tValues.abyssea.ruby >= 255) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Ruby:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.ruby, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ruby", EncodeColor(tValues.abyssea.ruby, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Ruby:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.ruby));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ruby", tValues.abyssea.ruby));
        end;
    elseif (token =="[Amber]") then
        if (tValues.abyssea.amber >= 255) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Amber:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.amber, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Amber", EncodeColor(tValues.abyssea.amber, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Amber:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.amber));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Amber", tValues.abyssea.amber));
        end;
    elseif (token =="[Gold]") then
        if (tValues.abyssea.golden >= 200) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Gold:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.golden, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Gold", EncodeColor(tValues.abyssea.golden, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Gold:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.golden));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Gold", tValues.abyssea.golden));
        end;
    elseif (token =="[Silver]") then
        if (tValues.abyssea.silvery >= 200) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Silver:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.silvery, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Silver", EncodeColor(tValues.abyssea.silvery, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Silver:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.silvery));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Silver", tValues.abyssea.silvery));
        end;
    elseif (token =="[Ebon]") then
        if (tValues.abyssea.ebon >= 200) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Ebon:");
                imgui.SameLine();
                imgui.TextColored(EncodeColor(tValues.abyssea.ebon, DefaultColors.FFXICappedValue));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ebon", EncodeColor(tValues.abyssea.ebon, DefaultColors.FFXICappedValue)));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text("Ebon:");
                imgui.SameLine();
                imgui.Text(tostring(tValues.abyssea.ebon));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplatePlain, "Ebon", tValues.abyssea.ebon));
        end;
    elseif (token == "[AssaultObjective]") then
        if (not points.settings.use_compact or points.use_both) then
            imgui.Text(tValues.assault.objective);
        end
        compactBar.textObjs[i]:SetText(tValues.assault.objective);
    elseif (token =="[NyzulFloor]") then
    elseif (token == "[EventTimer]") then
        local extractedTime = GetHMS(tValues.eventTimer);
        if (tValues.eventTimer <= 60) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.TextColored(DefaultColors.FFXICrimson, string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(EncodeColor(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec), DefaultColors.FFXICrimson));
        elseif (tValues.eventTimer <= 300) then
            if (not points.settings.use_compact or points.use_both) then
                imgui.TextColored(DefaultColors.FFXIAmber, string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(EncodeColor(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec), DefaultColors.FFXIYellow));
        else
            if (not points.settings.use_compact or points.use_both) then
                imgui.Text(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
            end
            compactBar.textObjs[i]:SetText(string.format(TemplateTimer, extractedTime.hr, extractedTime.min, extractedTime.sec));
        end
    elseif (token =="[DIV]") then
        if (not points.settings.use_compact or points.use_both) then
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
    UpdateFromZone(lastZone, true);    
    lastJob = player:GetMainJob();
    globalTimer = math.floor(os.clock());
    
    -- Defaults for compact bar
    LoadCompactBar();

    points.window_suffix = "_" .. playerEntity.Name .. playerEntity.ServerId;
    points.loaded = true;
end

function DrawConfigWindow()
    imgui.SetNextWindowSize({ 350, 250 }, ImGuiCond_FirstUseEver);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 10 });
    local strTokenDefault = { '' };
    local strTokenMasterd = "";
    local strTokenDynamis = "";
    if(points.config_is_open and imgui.Begin("Points Configuration", points.config_is_open, bit.bor(ImGuiWindowFlags_NoSavedSettings))) then
        imgui.Text("Token Displays:");

        imgui.End();
    end
    imgui.PopStyleVar(1);
end;