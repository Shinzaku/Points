require ("common");
require ("globals");
require ("helpers");
local ffi       = require('ffi');
local imgui = require("imgui");

local config = {};
config.uiSettings = {
    is_open = { false, },
    theme_index = { 1 },
    dragging = false,
    dd_source = 0,
    dd_target = 0,
}

config.drawWindow = function(settings)
    imgui.SetNextWindowSize({ 350, 250 }, ImGuiCond_FirstUseEver);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 10 });
    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    if(config.uiSettings.is_open[1] and imgui.Begin(("Points v%s"):fmt(addon.version), config.uiSettings.is_open, bit.bor(ImGuiWindowFlags_NoSavedSettings))) then
        imgui.BeginChild("conf_main", { 0, 90 }, true);
            imgui.Checkbox("Use Compact Bar", settings.use_compact_ui);
            if (imgui.Button("Reload", { 130, 20 })) then
                AshitaCore:GetChatManager():QueueCommand(-1, "/addon reload points");
            end
            if(imgui.Button("Restore Defaults", { 130, 20 })) then
                CopyTable(DefaultSettings, settings);
            end
            imgui.ShowHelp("Reset all settings to addon defaults", true);
        imgui.EndChild();
        if (imgui.BeginTabBar('##points_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            if (imgui.BeginTabItem('Tokens', nil)) then
                config.renderTokenTab(settings);
                imgui.EndTabItem();
            end
            if (imgui.BeginTabItem('Styles', nil)) then
                config.renderStylesTab(settings);
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
        imgui.End();
    end
    imgui.PopStyleColor(1);
    imgui.PopStyleVar(1);
end

config.renderTokenTab = function(settings)    
    imgui.Text("Token Settings");

    imgui.BeginChild("conf_token_list_left", { 0, 0 }, true);
        if (imgui.CollapsingHeader("Default")) then
            imgui.BeginChild("conf_token_default", { 0, 100 }, true);
                imgui.PushStyleColor(ImGuiCol_CheckMark, { 0.5, 0.5, 0.5, 1.0 });
                imgui.Checkbox(' Enabled', { true, });
                imgui.ShowHelp("Default token order; Cannot be disabled", true);
                imgui.PopStyleColor(1);
                imgui.NewLine();

                config.renderTokens(settings, "token_order_default", settings.token_enabled_mastered);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Mastered")) then
            imgui.BeginChild("conf_token_mastered", { 0, 100 }, true);
                config.renderTokens(settings, "token_order_mastered", settings.token_enabled_mastered);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Dynamis")) then
            imgui.BeginChild("conf_token_dynamis", { 0, 100 }, true);
                config.renderTokens(settings, "token_order_dynamis", settings.token_enabled_dynamis);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Assault")) then
            imgui.BeginChild("conf_token_assault", { 0, 100 }, true);
                config.renderTokens(settings, "token_order_assault", settings.token_enabled_assault);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Nyzul")) then
            imgui.BeginChild("conf_token_nyzul", { 0, 100 }, true);
                config.renderTokens(settings, "token_order_nyzul", settings.token_enabled_nyzul);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Abyssea")) then
            imgui.BeginChild("conf_token_abyssea", { 0, 100 }, true);
                config.renderTokens(settings, "token_order_abyssea", settings.token_enabled_abyssea);
            imgui.EndChild();
        end
    imgui.EndChild();
end

config.renderTokens = function(settings, listName, flag)
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    local tokenList = settings[listName];
    local defTokens = { tokenList, };
    local syntaxErr = tokenList:count("%[") ~= tokenList:count("%]");
    
    if (not listName:find("default")) then
        if (imgui.Checkbox(' Enabled', flag)) then
            UpdateTokenList(zone, false, job);
        end
        imgui.NewLine();
    end

    if (syntaxErr) then
        imgui.PushStyleColor(ImGuiCol_Border, { 1.0, 0.0, 0.0, 0.5 }); 
    end
    
    if (imgui.InputTextMultiline("", defTokens, 512, { 420, 40 }, ImGuiInputTextFlags_EnterReturnsTrue)) then
        settings[listName] = table.concat(defTokens);
        UpdateTokenList(zone, false, job);
    end

    if (syntaxErr) then
        imgui.PopStyleColor(1);
        imgui.ShowHelp("Missing opening or closing brackets for token", true);
    end
end

-- config.renderTokens = function(tokenList)    
--     imgui.PushStyleColor(ImGuiCol_Button, { 0.25, 0.25, 0.25, 1.0 });
--     local window_visible_x2 = imgui.GetWindowPos() + imgui.GetWindowContentRegionMax();
--     local last_button_x2 = 0;

--     if (config.uiSettings.dd_source ~= 0 and config.uiSettings.dd_source ~= 0) then
--         local source = config.uiSettings.dd_source;
--         local target = config.uiSettings.dd_target;
--         tokenList[source], tokenList[target] = tokenList[target], tokenList[source];
--     end

--     for i=1,#tokenList do
--         local v = tokenList[i];
--         if (v) then            
--             local button_szx = imgui.CalcTextSize(v) + 4;
--             local next_button_x2 = last_button_x2 + 4 + button_szx;
--             if next_button_x2 < window_visible_x2 then imgui.SameLine(0,1) end
--             imgui.SmallButton(v);
--             if (imgui.IsItemActive() and imgui.IsItemFocused() and not imgui.IsItemHovered()) then
--                 config.uiSettings.dd_source = i;
--                 imgui.BeginTooltip();
--                     imgui.Text(v);
--                 imgui.EndTooltip();
--             elseif (not imgui.IsItemActive() and imgui.IsItemHovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem) and config.uiSettings.dd_source ~= 0) then
--                 if (i ~= config.uiSettings.dd_source) then
--                     config.uiSettings.dd_target = i;
--                 end
--             elseif (i == config.uiSettings.dd_source and not imgui.IsItemActive()) then
--                 config.uiSettings.dd_source = 0;
--                 config.uiSettings.dd_target = 0;
--             end
            
--             last_button_x2 = imgui.GetItemRectMax();
--         end
--     end    
--     imgui.PopStyleColor(1);
-- end

config.renderStylesTab = function(settings)
    imgui.Text("Style Settings");
    imgui.BeginChild("conf_styles", { 0, 0 }, true);
    if (imgui.BeginTabBar('##points_style_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
        if (imgui.BeginTabItem('Global', nil)) then
            imgui.Text("Font");
            imgui.BeginChild("conf_font", { 0, 115 }, true);
                imgui.ColorEdit4('\xef\x94\xbf Main Color', settings.colors.mainText);
                imgui.ColorEdit4('\xef\x94\xbf Capped Value', settings.colors.cappedValue);
                imgui.ColorEdit4('\xef\x94\xbf Chain Timer', settings.colors.chainTimer);
                if (imgui.Button("Reset", { 60, 20 })) then
                    settings.colors.mainText = { 1.0, 1.0, 1.0, 1.0 };
                    CopyTable(DefaultColors.FFXICappedValue, settings.colors.cappedValue);
                    CopyTable(DefaultColors.FFXIYellow, settings.colors.chainTimer);
                end
            imgui.EndChild();

            imgui.Text("Background");
            imgui.BeginChild("conf_bg", { 0, 95 }, true);
                imgui.ColorEdit4('\xef\x94\xbf Main Color', settings.colors.bg);
                imgui.ColorEdit4('\xef\x94\xbf Border Color', settings.colors.bgBorder);
                if (imgui.Button("Reset", { 60, 20 })) then
                    CopyTable(DefaultColors.FFXIGreyBg, settings.colors.bg);
                    CopyTable(DefaultColors.FFXIGreyBorder, settings.colors.bgBorder);
                end
            imgui.EndChild();
            
            imgui.Text("Theme Selection");
            imgui.BeginChild("conf_theme", { 0, 40 }, true);
                local themePaths = ashita.fs.get_directory(("%s\\themes\\"):fmt(addon.path));
                local cTheme = settings.theme;
                if (imgui.BeginCombo("\xef\x89\x87 Theme", themePaths[config.getThemeIndex(cTheme)[1]], ImGuiComboFlags_None)) then
                    for i,v in pairs(themePaths) do
                        local selected = i == config.uiSettings.theme_index[1];
                        if (imgui.Selectable(themePaths[i], selected)) then
                            config.uiSettings.theme_index[1] = i;
                            settings.theme = themePaths[i];
                            ReloadImages(settings.theme);
                        end
                        if (selected) then
                            imgui.SetItemDefaultFocus();
                        end
                    end

                    imgui.EndCombo();
                end
                imgui.ShowHelp("Select job icon theme\n- Requires both large and compact icons to exist\n- See default for example (\\addons\\points\\themes\\)");
            imgui.EndChild();

            imgui.Text("Misc");
            imgui.BeginChild("conf_misc", { 0, 70 }, true);
                local sep = { settings.num_separator, };
                if (imgui.InputText("Radix Character", sep, 2)) then
                    settings.num_separator = sep[1];
                end            
                imgui.ShowHelp("Decimal separator for every thousandth place (1000 vs 1,000)", true);

                local rate = { settings.rate_reset_timer, };
                if (imgui.InputInt("Chain Rate Reset", rate)) then
                    settings.rate_reset_timer = rate[1];
                end
                imgui.ShowHelp("Number of seconds until the chain rate calculation resets", true);
            imgui.EndChild();

            imgui.EndTabItem();
        end
        if (imgui.BeginTabItem('Compact', nil)) then
            imgui.Text("Position")
            imgui.BeginChild("conf_pos_compact", { 0, 75 }, true);
                local cx = { settings.compact.x, };
                local cy = { settings.compact.y, };
                local winRect = AshitaCore:GetProperties():GetFinalFantasyRect();
                if (imgui.SliderInt("\xef\x8c\xb7X", cx, 0, winRect.right, "%dpx")) then
                    settings.compact.x = cx[1];
                end
                if (imgui.SliderInt("\xef\x8c\xb8Y", cy, 0, winRect.bottom, "%dpx")) then
                    settings.compact.y = cy[1];
                end
            imgui.EndChild();

            imgui.Text("Font");
            imgui.BeginChild("conf_font_compact", { 0, 95 }, true);
                local height = { settings.compact.font.font_height, };
                if (imgui.SliderInt("\xef\x95\x88 Height", height, 1, 99, "%dpx")) then
                    settings.compact.font.font_height = height[1];
                end
                local ffamily = { settings.compact.font.font_family, };
                if (imgui.InputText("\xef\x80\xb1 Font Family", ffamily, 255)) then
                    settings.compact.font.font_family = table.concat(ffamily);
                end
                if (imgui.Button("Reset", { 60, 20 })) then
                    settings.compact.font.font_height = DefaultSettings.compact.font.font_height;
                    settings.compact.font.font_family = DefaultSettings.compact.font.font_family;
                end
            imgui.EndChild();
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end
    imgui.EndChild();
end

config.getThemeIndex = function(name)
    local themePaths = ashita.fs.get_directory(("%s\\themes\\"):fmt(addon.path));
    for i,v in pairs(themePaths) do
        if (v == name) then
            return { i };
        end
    end
    return { "default", };
end

return config;