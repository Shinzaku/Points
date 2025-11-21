require ("common");
require ("globals");
require ("helpers");
local ffi       = require('ffi');
local imgui = require("imgui");

local config = {};
config.uiSettings = {
    is_open = { false, },
    theme_index = { 1 },
    changed = false,
    tokenEditing = false,
}

config.drawWindow = function(settings)
    imgui.SetNextWindowSize({ 450, 350 }, ImGuiCond_FirstUseEver);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 10 });
    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    if(config.uiSettings.is_open[1] and imgui.Begin(("Points v%s"):fmt(addon.version), config.uiSettings.is_open, ImGuiWindowFlags_NoSavedSettings)) then
        imgui.BeginChild("conf_main", { 0, 90 }, ImGuiChildFlags_Borders);
            if (imgui.Checkbox("Use Compact Bar", settings.use_compact_ui)) then
                config.uiSettings.changed = true;
            end
            if (imgui.Button("Reload", { 130, 20 })) then
                AshitaCore:GetChatManager():QueueCommand(-1, "/addon reload points");
            end
            if(imgui.Button("Restore Defaults", { 130, 20 })) then
                CopyTable(DefaultSettings, settings);
                config.uiSettings.changed = true;
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
    imgui.Text("- Click-and-drag to reorder\n- Double-click to add or remove tokens");

    imgui.BeginChild("conf_token_list_left", { 0, 0 }, ImGuiChildFlags_Borders);
        if (imgui.CollapsingHeader("Default")) then
            imgui.BeginChild("conf_token_default", { 0, 250 }, ImGuiChildFlags_Borders);
                imgui.PushStyleColor(ImGuiCol_CheckMark, { 0.5, 0.5, 0.5, 1.0 });
                imgui.Checkbox(' Enabled', { true, });
                imgui.ShowHelp("Default token order; Cannot be disabled", true);
                imgui.PopStyleColor(1);
                imgui.NewLine();

                local tempBool = T{ true };
                config.renderTokens(settings, "token_order_default", tempBool);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Mastered")) then
            imgui.BeginChild("conf_token_mastered", { 0, 250 }, ImGuiChildFlags_Borders);
                config.renderTokens(settings, "token_order_mastered", settings.token_enabled_mastered);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Dynamis")) then
            imgui.BeginChild("conf_token_dynamis", { 0, 250 }, ImGuiChildFlags_Borders);
                config.renderTokens(settings, "token_order_dynamis", settings.token_enabled_dynamis);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Assault")) then
            imgui.BeginChild("conf_token_assault", { 0, 250 }, ImGuiChildFlags_Borders);
                config.renderTokens(settings, "token_order_assault", settings.token_enabled_assault);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Nyzul")) then
            imgui.BeginChild("conf_token_nyzul", { 0, 250 }, ImGuiChildFlags_Borders);
                config.renderTokens(settings, "token_order_nyzul", settings.token_enabled_nyzul);
            imgui.EndChild();
        end
        if (imgui.CollapsingHeader("Abyssea")) then
            imgui.BeginChild("conf_token_abyssea", { 0, 250 }, ImGuiChildFlags_Borders);
                config.renderTokens(settings, "token_order_abyssea", settings.token_enabled_abyssea);
            imgui.EndChild();
        end
    imgui.EndChild();
end

config.renderTokens = function(settings, listName, flag)
    if (not listName:find("default")) then
        if (imgui.Checkbox(' Enabled', flag)) then
            config.uiSettings.changed = true;
        end
        imgui.NewLine();
    end

    local tokenArr = ashita.regex.split(settings[listName], " ");
    local iRemove = 0;
    local numDiv = 0;
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.15, 0.15, 0.18, 1.0 });

    imgui.BeginGroup();
    imgui.TextUnformatted("Current");
    imgui.BeginChild("active_tokens_" .. listName, { 200, 150 }, ImGuiChildFlags_Borders);
        for i=1,#tokenArr do
            if (tokenArr[i]:contains("[DIV]")) then
                numDiv = numDiv + 1;
            end
            if (tokenArr[i] == "[DIV]") then
                tokenArr[i] = ("[DIV]##%d"):format(numDiv);
                config.uiSettings.tokenEditing = true;
            end

            local currItem = tokenArr[i];
            imgui.Selectable(currItem, false, ImGuiSelectableFlags_AllowDoubleClick);
            if (imgui.IsItemClicked(ImGuiMouseButton_Left) and imgui.IsMouseDoubleClicked(ImGuiMouseButton_Left)) then
                iRemove = i;
            elseif (imgui.IsItemActive() and not imgui.IsItemHovered()) then
                local mdX, mdY = imgui.GetMouseDragDelta(ImGuiMouseButton_Left);
                local next = i + 1;
                if (mdY < 0) then
                    next = i - 1;
                end
                if (next >= 1 and next <= #tokenArr) then
                    tokenArr[i] = tokenArr[next];
                    tokenArr[next] = currItem;
                    config.uiSettings.tokenEditing = true;
                    imgui.ResetMouseDragDelta();
                end
            end
        end
    if (iRemove > 0) then
        table.remove(tokenArr, iRemove);
        config.uiSettings.tokenEditing = true;
    end
    imgui.EndChild();
    imgui.EndGroup();

    imgui.SameLine();
    imgui.BeginGroup();
    imgui.TextUnformatted("Available");
    imgui.BeginChild("available_tokens_" .. listName, { -1, 150 }, ImGuiChildFlags_Borders);
        if (imgui.BeginTable("token_table_" .. listName, 3)) then
            for i,v in ipairs(AvailableTokens) do
                if ((i - 1) % 3 == 0) then
                    imgui.TableNextRow();
                end
                if (table.contains(tokenArr, v.key) and v.key ~= "[DIV]") then
                    imgui.TableNextColumn();
                    imgui.Selectable(("%s##%s"):format(v.key, listName), false, ImGuiSelectableFlags_Disabled);
                else
                    imgui.TableNextColumn();
                    imgui.Selectable(("%s##%s"):format(v.key, listName), false, ImGuiSelectableFlags_AllowDoubleClick);
                end

                if (imgui.IsItemClicked(ImGuiMouseButton_Left) and imgui.IsMouseDoubleClicked(ImGuiMouseButton_Left)) then
                    table.insert(tokenArr, v.key);
                    config.uiSettings.tokenEditing = true;
                end

                if (v.desc ~= "") then
                    imgui.ShowHelp(v.desc, true);
                end
            end
            imgui.EndTable();
        end
    imgui.EndChild();
    imgui.EndGroup();

    imgui.PopStyleColor(1);

    if (config.uiSettings.tokenEditing) then
        numDiv = 0;
        for i,v in ipairs(tokenArr) do
            if (v:contains("[DIV]")) then
                numDiv = numDiv + 1;
                v = ("[DIV]##%d"):format(numDiv);
            end
        end

        settings[listName] = table.concat(tokenArr, " ");
        if (settings[listName] == " ") then
            settings[listName] = "";
        end
    end

    if (config.uiSettings.tokenEditing and imgui.IsMouseReleased(ImGuiMouseButton_Left)) then
        config.uiSettings.tokenEditing = false;
        config.uiSettings.changed = true;
    end
end

config.renderStylesTab = function(settings)
    imgui.Text("Style Settings");
    imgui.BeginChild("conf_styles", { 0, 0 }, ImGuiChildFlags_Borders);
    if (imgui.BeginTabBar('##points_style_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
        if (imgui.BeginTabItem('Global', nil)) then
            imgui.Text("Font");
            imgui.BeginChild("conf_font", { 0, 115 }, ImGuiChildFlags_Borders);
                if (imgui.ColorEdit4('\xef\x94\xbf Main Color', settings.colors.mainText)) then
                    config.uiSettings.changed = true;
                end
                if (imgui.ColorEdit4('\xef\x94\xbf Capped Value', settings.colors.cappedValue)) then
                    config.uiSettings.changed = true;
                end
                if (imgui.ColorEdit4('\xef\x94\xbf Chain Timer', settings.colors.chainTimer)) then
                    config.uiSettings.changed = true;
                end
                if (imgui.Button("Reset", { 60, 20 })) then
                    settings.colors.mainText = { 1.0, 1.0, 1.0, 1.0 };
                    CopyTable(DefaultColors.FFXICappedValue, settings.colors.cappedValue);
                    CopyTable(DefaultColors.FFXIYellow, settings.colors.chainTimer);
                    config.uiSettings.changed = true;
                end
            imgui.EndChild();

            imgui.Text("Background");
            imgui.BeginChild("conf_bg", { 0, 95 }, ImGuiChildFlags_Borders);
                if (imgui.ColorEdit4('\xef\x94\xbf Main Color', settings.colors.bg)) then
                    config.uiSettings.changed = true;
                end
                if (imgui.ColorEdit4('\xef\x94\xbf Border Color', settings.colors.bgBorder)) then
                    config.uiSettings.changed = true;
                end
                if (imgui.Button("Reset", { 60, 20 })) then
                    CopyTable(DefaultColors.FFXIGreyBg, settings.colors.bg);
                    CopyTable(DefaultColors.FFXIGreyBorder, settings.colors.bgBorder);
                    config.uiSettings.changed = true;
                end
            imgui.EndChild();
            
            imgui.Text("Theme Selection");
            imgui.BeginChild("conf_theme", { 0, 40 }, ImGuiChildFlags_Borders);
                local themePaths = ashita.fs.get_directory(("%s\\themes\\"):fmt(addon.path));
                local cTheme = settings.theme;
                if (imgui.BeginCombo("\xef\x89\x87 Theme", themePaths[config.getThemeIndex(cTheme)[1]], ImGuiComboFlags_None)) then
                    for i,v in pairs(themePaths) do
                        local selected = i == config.uiSettings.theme_index[1];
                        if (imgui.Selectable(themePaths[i], selected)) then
                            config.uiSettings.theme_index[1] = i;
                            settings.theme = themePaths[i];
                            ReloadImages(settings.theme);
                            config.uiSettings.changed = true;
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
            imgui.BeginChild("conf_misc", { 0, 100 }, ImGuiChildFlags_Borders);
                local sep = { settings.num_separator, };
                if (imgui.Checkbox("Hide on events", settings.hide_on_event)) then
                    config.uiSettings.changed = true;
                end
                imgui.ShowHelp("Toggles the bar displaying during cutscenes and NPC menu dialogues", true);

                if (imgui.Checkbox("Use Job Icon", settings.use_job_icon)) then
                    config.uiSettings.changed = true;
                end
                imgui.ShowHelp("Display the job icon on the far left of the bar with current job level", true);

                if (imgui.Checkbox("Show LP/HR as Merits/HR", settings.show_lphr)) then
                    config.uiSettings.changed = true;
                end
                imgui.ShowHelp("Toggles showing limit points earned per hours vs merits earned per hour", true);

                if (imgui.InputText("Radix Character", sep, 2)) then
                    settings.num_separator = sep[1];
                    config.uiSettings.changed = true;
                end
                imgui.ShowHelp("Decimal separator for every thousandth place (1000 vs 1,000)", true);

                local rate = { settings.rate_reset_timer, };
                if (imgui.InputInt("Chain Rate Reset", rate)) then
                    settings.rate_reset_timer = rate[1];
                    config.uiSettings.changed = true;
                end
                imgui.ShowHelp("Number of seconds until the chain rate calculation resets", true);
            imgui.EndChild();

            imgui.EndTabItem();
        end
        if (imgui.BeginTabItem('Full', nil)) then
            imgui.Text("Position");
            imgui.BeginChild("conf_pos_full", { 0, 75 }, ImGuiChildFlags_Borders);
                local cx = { settings.bar_x, };
                local cy = { settings.bar_y, };
                local winRect = AshitaCore:GetProperties():GetFinalFantasyRect();
                if (imgui.SliderInt("\xef\x8c\xb7X", cx, 0, winRect.right, "%dpx")) then
                    settings.bar_x = cx[1];
                    config.uiSettings.changed = true;
                end
                if (imgui.SliderInt("\xef\x8c\xb8Y", cy, 0, winRect.bottom, "%dpx")) then
                    settings.bar_y = cy[1];
                    config.uiSettings.changed = true;
                end
            imgui.EndChild();

            imgui.Text("Font");
            imgui.BeginChild("conf_font_full", { 0, 65 }, ImGuiChildFlags_Borders);
                local scale = { settings.font_scale, };
                if (imgui.SliderFloat("\xef\x95\x88 Scale", scale, 1, 10, "%.1f")) then
                    settings.font_scale = scale[1];
                    config.uiSettings.changed = true;
                end
                if (imgui.Button("Reset", { 60, 20 })) then
                    settings.font_scale = 1.0;
                    settings.bar_x = 130;
                    settings.bar_y = 15;
                    config.uiSettings.changed = true;
                end
            imgui.EndChild();
            imgui.EndTabItem();
        end
        if (imgui.BeginTabItem('Compact', nil)) then
            imgui.Text("Position");
            imgui.BeginChild("conf_pos_compact", { 0, 75 }, ImGuiChildFlags_Borders);
                local cx = { settings.compact.x, };
                local cy = { settings.compact.y, };
                local winRect = AshitaCore:GetProperties():GetFinalFantasyRect();
                if (imgui.SliderInt("\xef\x8c\xb7X", cx, 0, winRect.right, "%dpx")) then
                    settings.compact.x = cx[1];
                    config.uiSettings.changed = true;
                end
                if (imgui.SliderInt("\xef\x8c\xb8Y", cy, 0, winRect.bottom, "%dpx")) then
                    settings.compact.y = cy[1];
                    config.uiSettings.changed = true;
                end
            imgui.EndChild();

            imgui.Text("Font");
            imgui.BeginChild("conf_font_compact", { 0, 95 }, ImGuiChildFlags_Borders);
                local height = { settings.compact.font.font_height, };
                if (imgui.SliderInt("\xef\x95\x88 Height", height, 1, 99, "%dpx")) then
                    settings.compact.font.font_height = height[1];
                    config.uiSettings.changed = true;
                end
                local ffamily = { settings.compact.font.font_family, };
                if (imgui.InputText("\xef\x80\xb1 Font Family", ffamily, 255)) then
                    settings.compact.font.font_family = table.concat(ffamily);
                    config.uiSettings.changed = true;
                end
                if (imgui.Button("Reset", { 60, 20 })) then
                    settings.compact.font.font_height = DefaultSettings.compact.font.font_height;
                    settings.compact.font.font_family = DefaultSettings.compact.font.font_family;
                    config.uiSettings.changed = true;
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