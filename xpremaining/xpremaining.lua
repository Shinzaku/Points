--[[
    XP Remaining - Ashita v4 Addon
    Tracks remaining XP bonus from Dedication buff (experience rings like Echad, Empress, etc.)

    Author: Generated for FFXI
    Version: 1.0.1

    Usage:
        /xpr or /xpremaining - Toggle window
        /xpr set <amount> - Set your max bonus (e.g., /xpr set 2250)
        /xpr rate <rate> - Set bonus rate (e.g., /xpr rate 1.5 for +150%)
        /xpr reset - Reset tracking
        /xpr help - Show all commands
]]--

addon.name    = 'xpremaining'
addon.author  = 'XPRemaining'
addon.version = '1.0.1'
addon.desc    = 'Displays remaining XP bonus from Dedication buff'
addon.link    = ''

require('common')
local imgui = require('imgui')
local settings = require('settings')
local chat = require('chat')

-- Dedication buff ID (249 = Dedication from experience rings)
local DEDICATION_BUFF_ID = 249

-- XP Message IDs
local XP_MESSAGE_NORMAL = 8      -- Regular XP gain
local XP_MESSAGE_CHAIN = 105     -- XP gain with chain bonus

-- Default settings (must use T{} for Ashita v4 settings library)
local default_settings = T{
    max_bonus = 2250,         -- Maximum bonus XP (user specified 2250)
    bonus_rate = 1.5,         -- Bonus rate (1.5 = +150%)
    visible = true,           -- Window visibility
    locked = false,           -- Lock window position
    show_percentage = true,   -- Show percentage remaining
    window_x = 100,           -- Window X position
    window_y = 100,           -- Window Y position
    font_scale = 1.0,         -- Font scale
    auto_reset_on_buff_loss = true,  -- Reset tracking when buff is lost
}

-- Runtime state
local xpr = T{
    settings = nil,           -- Will be loaded in load event
    bonus_used = 0,           -- Total bonus XP consumed
    is_tracking = false,      -- Currently tracking (Dedication active)
    last_had_dedication = false,
    window_state = { true },
}

--[[
    Calculate bonus XP from total XP gained
    When you have +150% bonus, total XP = base * 2.5
    So bonus portion = total * (bonus_rate / (1 + bonus_rate))
]]--
local function calculate_bonus_from_total(total_xp, bonus_rate)
    return math.floor(total_xp * (bonus_rate / (1 + bonus_rate)))
end

--[[
    Check if player has Dedication buff
]]--
local function has_dedication_buff()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if player == nil then
        return false
    end

    local buffs = player:GetBuffs()
    if buffs == nil then
        return false
    end

    for i = 0, 31 do
        if buffs[i] == DEDICATION_BUFF_ID then
            return true
        end
    end

    return false
end

--[[
    Get remaining bonus XP
]]--
local function get_remaining_bonus()
    if xpr.settings == nil then return 0 end
    return math.max(0, xpr.settings.max_bonus - xpr.bonus_used)
end

--[[
    Get remaining percentage
]]--
local function get_remaining_percentage()
    if xpr.settings == nil or xpr.settings.max_bonus <= 0 then
        return 0
    end
    return (get_remaining_bonus() / xpr.settings.max_bonus) * 100
end

--[[
    Reset tracking
]]--
local function reset_tracking()
    xpr.bonus_used = 0
    xpr.is_tracking = false
    print(chat.header(addon.name):append(chat.message('XP bonus tracking reset.')))
end

--[[
    Handle incoming packets
    Packet 0x2D: Kill Message - sent when gaining XP/LP/CP/JP from defeating mobs
        - 0x10: Param 1 (XP gained) - unsigned int
        - 0x18: Message ID - unsigned short
    Packet 0x29: Action Message - simple battle messages (Abyssea XP, etc.)
        - 0x0C: Param 1 (XP value) - unsigned int
        - 0x18: Message ID - unsigned short
]]--
ashita.events.register('packet_in', 'xpremaining_packet_in_cb', function(e)
    -- Skip if settings not loaded yet
    if xpr.settings == nil then
        return
    end

    -- Only process if we have Dedication buff
    if not has_dedication_buff() then
        return
    end

    -- Packet 0x2D - Kill Message (XP/LP/CP/JP gain)
    if e.id == 0x2D then
        -- Message ID at offset 0x18, use modulo 1024 to get base message type
        local msg_type = struct.unpack('H', e.data_modified, 0x18 + 1) % 1024

        -- Message types for XP gain: 8 (normal XP), 105 (XP with chain)
        if msg_type == XP_MESSAGE_NORMAL or msg_type == XP_MESSAGE_CHAIN then
            -- XP value at offset 0x10
            local xp_gained = struct.unpack('I', e.data_modified, 0x10 + 1)

            if xp_gained > 0 then
                -- Calculate bonus portion of XP
                local bonus_xp = calculate_bonus_from_total(xp_gained, xpr.settings.bonus_rate)
                xpr.bonus_used = xpr.bonus_used + bonus_xp
                xpr.is_tracking = true

                -- Check if we've exceeded the max bonus
                if xpr.bonus_used >= xpr.settings.max_bonus then
                    print(chat.header(addon.name):append(chat.warning('Dedication bonus depleted!')))
                end
            end
        end
    end

    -- Packet 0x29 - Action Message (also used for XP in some cases like Abyssea)
    if e.id == 0x29 then
        local msg_type = struct.unpack('H', e.data_modified, 0x18 + 1) % 1024

        if msg_type == XP_MESSAGE_NORMAL or msg_type == XP_MESSAGE_CHAIN then
            -- XP value at offset 0x0C for action messages
            local xp_gained = struct.unpack('I', e.data_modified, 0x0C + 1)

            if xp_gained > 0 then
                local bonus_xp = calculate_bonus_from_total(xp_gained, xpr.settings.bonus_rate)
                xpr.bonus_used = xpr.bonus_used + bonus_xp
                xpr.is_tracking = true

                if xpr.bonus_used >= xpr.settings.max_bonus then
                    print(chat.header(addon.name):append(chat.warning('Dedication bonus depleted!')))
                end
            end
        end
    end
end)

--[[
    Render ImGui window
]]--
ashita.events.register('d3d_present', 'xpremaining_present_cb', function()
    -- Skip if settings not loaded yet
    if xpr.settings == nil then
        return
    end

    -- Check buff status for auto-reset
    local has_buff = has_dedication_buff()

    if xpr.settings.auto_reset_on_buff_loss then
        if xpr.last_had_dedication and not has_buff then
            -- Buff was lost, reset tracking
            reset_tracking()
        end
    end
    xpr.last_had_dedication = has_buff

    -- Don't render if not visible
    if not xpr.settings.visible then
        return
    end

    -- Set up window flags
    local flags = bit.bor(
        ImGuiWindowFlags_NoTitleBar,
        ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_AlwaysAutoResize
    )

    if xpr.settings.locked then
        flags = bit.bor(flags,
            ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoResize
        )
    end

    -- Begin window
    if imgui.Begin('XP Remaining', xpr.window_state, flags) then
        local remaining = get_remaining_bonus()
        local percentage = get_remaining_percentage()

        -- Status indicator
        if has_buff then
            imgui.Text('Dedication: ACTIVE')
        else
            imgui.Text('Dedication: Inactive')
        end

        imgui.Separator()

        -- Display remaining XP
        imgui.Text(string.format('Remaining: %d / %d', remaining, xpr.settings.max_bonus))

        if xpr.settings.show_percentage then
            imgui.Text(string.format('(%.1f%%)', percentage))
        end

        -- Save window position if unlocked and moved
        if not xpr.settings.locked then
            local pos_x, pos_y = imgui.GetWindowPos()
            if pos_x and pos_y then
                xpr.settings.window_x = pos_x
                xpr.settings.window_y = pos_y
            end
        end
    end
    imgui.End()
end)

--[[
    Helper function for printing messages
]]--
local function msg(text)
    print(chat.header(addon.name):append(chat.message(text)))
end

local function msg_error(text)
    print(chat.header(addon.name):append(chat.error(text)))
end

local function msg_warn(text)
    print(chat.header(addon.name):append(chat.warning(text)))
end

--[[
    Handle commands
]]--
ashita.events.register('command', 'xpremaining_command_cb', function(e)
    local args = e.command:args()

    if #args == 0 or (args[1] ~= '/xpr' and args[1] ~= '/xpremaining') then
        return
    end

    e.blocked = true

    -- Skip if settings not loaded yet
    if xpr.settings == nil then
        msg_error('Settings not loaded yet.')
        return
    end

    if #args == 1 then
        -- Toggle visibility
        xpr.settings.visible = not xpr.settings.visible
        msg('Window ' .. (xpr.settings.visible and 'shown' or 'hidden'))
        settings.save()
        return
    end

    local cmd = string.lower(args[2])

    if cmd == 'help' then
        msg('Commands:')
        msg('  /xpr - Toggle window visibility')
        msg('  /xpr show - Show window')
        msg('  /xpr hide - Hide window')
        msg('  /xpr reset - Reset XP tracking')
        msg('  /xpr set <amount> - Set max bonus (e.g., /xpr set 2250)')
        msg('  /xpr rate <rate> - Set bonus rate (e.g., /xpr rate 1.5 for +150%)')
        msg('  /xpr lock - Toggle window lock')
        msg('  /xpr status - Show current status')

    elseif cmd == 'show' then
        xpr.settings.visible = true
        msg('Window shown')
        settings.save()

    elseif cmd == 'hide' then
        xpr.settings.visible = false
        msg('Window hidden')
        settings.save()

    elseif cmd == 'reset' then
        reset_tracking()

    elseif cmd == 'set' then
        if #args >= 3 then
            local amount = tonumber(args[3])
            if amount and amount > 0 then
                xpr.settings.max_bonus = amount
                xpr.bonus_used = 0  -- Reset on new max
                msg('Max bonus set to ' .. amount)
                settings.save()
            else
                msg_error('Invalid amount. Usage: /xpr set <amount>')
            end
        else
            msg_error('Usage: /xpr set <amount>')
        end

    elseif cmd == 'rate' then
        if #args >= 3 then
            local rate = tonumber(args[3])
            if rate and rate > 0 then
                xpr.settings.bonus_rate = rate
                msg('Bonus rate set to +' .. (rate * 100) .. '%')
                settings.save()
            else
                msg_error('Invalid rate. Usage: /xpr rate <rate>')
            end
        else
            msg_error('Usage: /xpr rate <rate> (e.g., 1.5 for +150%)')
        end

    elseif cmd == 'lock' then
        xpr.settings.locked = not xpr.settings.locked
        msg('Window ' .. (xpr.settings.locked and 'locked' or 'unlocked'))
        settings.save()

    elseif cmd == 'status' then
        local has_buff = has_dedication_buff()
        msg('Status:')
        msg('  Dedication: ' .. (has_buff and 'Active' or 'Inactive'))
        msg('  Max Bonus: ' .. xpr.settings.max_bonus)
        msg('  Bonus Rate: +' .. (xpr.settings.bonus_rate * 100) .. '%')
        msg('  Used: ' .. xpr.bonus_used)
        msg('  Remaining: ' .. get_remaining_bonus())
        msg('  Percentage: ' .. string.format('%.1f%%', get_remaining_percentage()))

    else
        msg_error('Unknown command. Use /xpr help for commands.')
    end
end)

--[[
    Load event
]]--
ashita.events.register('load', 'xpremaining_load_cb', function()
    -- Load settings
    xpr.settings = settings.load(default_settings)

    msg('Loaded. Use /xpr help for commands.')
    msg('Current max bonus: ' .. xpr.settings.max_bonus .. ' (use /xpr set <amount> to change)')
end)

--[[
    Unload event
]]--
ashita.events.register('unload', 'xpremaining_unload_cb', function()
    settings.save()
    msg('Unloaded. Settings saved.')
end)
