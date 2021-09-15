-- HelpString = "\30\67- \30\71config\30\67 - Brings up the configuration window\n" ..
--              "\30\67- \30\71compact\30\67 - Enables/disables the compact bar\n" ..
--              "\30\67Check the configuration window for all available options\n" ..
--              "\30\67If issues found, please submit an issue at:\n\30\92https://github.com/Shinzaku/Ashita4-Addons/points/";

HelpString = "\30\67- \30\71fsize\30\67 - Sets compact bar font size\n" ..
             "\30\67- \30\71ffamily\30\67 - Sets compact bar font family\n" ..
             "\30\67- \30\71compact\30\67 - Toggles the compact bar\n" ..
             "\30\67- \30\71theme\30\67 - Sets icon theme to the given folder name (need to reload; see default)\n" ..
             --"\30\67- \30\71color\30\67 - Sets default font color to r g b a values (0 - 255)\n" ..
             "\30\67- \30\71bgcolor\30\67 - Sets background color to r g b a values (0 - 255) or default\n" ..
             "\30\67- \30\71border\30\67 - Sets border color to r g b a values (0 - 255) or default\n" ..
             --"\30\67- \30\71config\30\67 - Brings up the configuration window\n" ..
             "\30\67Click (or shift-click for compact) and drag to reposition\n\30\67Configuration is saved when unloaded\n" ..
             "\30\67If issues found, please submit an issue at:\n\30\92https://github.com/Shinzaku/Ashita4-Addons/tree/main/points";

DefaultColors = {}
DefaultColors.FFXICappedValue = { 0.23, 0.67, 0.91, 1.0 };
DefaultColors.FFXIGreyBg = { 0.08, 0.08, 0.08, 0.8 };
DefaultColors.FFXIGreyBorder = { 0.69, 0.68, 0.78, 1.0 };
DefaultColors.FFXIYellow = { 0.91, 0.91, 0.23, 1.0 };
DefaultColors.FFClassicBlue = { 0.07, 0.07, 0.58, 1.0 };
DefaultColors.FFXICrimson = { 0.93, 0.12, 0.12, 1.0 };
DefaultColors.FFXIAzure = { 0.52, 0.76, 1.0, 1.0 };
DefaultColors.FFXIAmber = { 0.81, 0.81, 0.50, 1.0 };
DefaultColors.FFXIAlibaster = { 0.60, 0.60, 0.78, 1.0 };
DefaultColors.FFXIObsidian = { 0.12, 0.12, 0.12, 1.0 };
DefaultColors.FFXILightGrey = { 0.50, 0.50, 0.50, 1.0 };
DefaultColors.FFXIDarkGrey = { 0.25, 0.25, 0.25, 1.0 };

TemplateRatio = "%s: %s/%s";
DefaultSettings = T{
    use_compact = false,
    compact = T{
        hPadding = 8,
        x = 0,
        y = -17,
        font = T{
            visible = true,
            color = 0xFFFFFFFF,
            font_family = "Tahoma",
            font_height = 11,
        }
    },
    font_scale = 1.0,
    bar_x = 130,
    bar_y = 15,
    decimal = ".",
    num_separator = "",
    bar_divider = "\xef\x85\x82",
    compact_divider = "|",
    bg_color = DefaultColors.FFXIGreyBg,
    bg_border_color = DefaultColors.FFXIGreyBorder,
    token_order_default = "[XP] [Merits] [XPHour] [XPChain] [DIV] [CP] [JP] [JPHour] [CPChain] [DIV] [Sparks] [DIV] [Accolades]",
    token_order_dynamis = "[DynamisKI] [DIV] [EventTimer]",
    token_order_abyssea = "[Pearl] [Azure] [Ruby] [Amber] [Gold] [Silver] [Ebon] [DIV] [EventTimer]",
    token_order_assault = "[AssaultObjective] [DIV] [EventTimer]",
    token_order_nyzul = "[NyzulFloor] [DIV] [NyzulObjective] [DIV] [EventTimer]",
    token_order_voidwatch = "[VWRed] [VWBlue] [VWGreen] [VWYellow] [VWWhite]",
    theme = "default",
}
WrapperSettings = T{
    visible = true,
    color = 0xFFFFFFFF,
    font_family = "Tahoma",
    font_height = 11,
}
JobIconSettings = T{
    visible = true,
    color = 0xFFFFFFFF,
    font_family = "Tahoma",
    font_height = 11,
}

TemplateBracket = "[%s]";
TemplateRate = "(%.1f %s/hr)";
TemplateRateAbbr = "(%s %s/hr)";
TemplateChain = "%s#>%s (%ss)";
TemplatePlain = "%s: %s";
TemplateTimer = "%02d:%02d:%02d";

DynamisExtensionOrig = { 600, 600, 600, 900, 900 };
DynamisExtensionDream = { 600, 600, 600, 600, 1200 };
DynamisMapping = { [134] = DynamisExtensionOrig, [135] = DynamisExtensionOrig,
                   [185] = DynamisExtensionOrig, [186] = DynamisExtensionOrig, [187] = DynamisExtensionOrig, [188] = DynamisExtensionOrig,
                   [39] = DynamisExtensionDream, [40] = DynamisExtensionDream, [41] = DynamisExtensionDream, [42] = DynamisExtensionDream };
AbysseaMapping = { [15] = "Konschtat", [45] = "Tahrongi", [132] = "La Theine", [215] = "Attohwa", [216] = "Misareaux", [217] = "Vunkerl", [218] = "Altepa",
                    [253] = "Uleguerand", [254] = "Garuberg", [255] = "Empyreal Paradox", };
AbysseaLightEstimates = { ["pearlescent"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 230 },
                        ["golden"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 200 },
                        ["silvery"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 200 },
                        ["ebon"] = { ["feeble"] = 0, ["faint"] = 1, ["mild"] = 2, ["strong"] = 3, ["intense"] = 0, ["max"] = 200 },
                        ["azure"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 },
                        ["ruby"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 },
                        ["amber"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 }, };
AssaultMapping = { [69] = "Leujaoam Sanctum", [66] = "Mamool Ja Training Grounds", [63] = "Lebros Cavern", [56] = "Periqia", [55] = "Ilrusi Atoll" };
NyzulMapping = { [77] = "Nyzul Isle" };

MessageMatch = {};
MessageMatch.ObtainedKI = "Obtained key item: \x1E\x03(.*)\x1E\x01";
MessageMatch.DynaTimeEntry = "(\\d+) minutes .* remaining in Dynamis";
MessageMatch.DynaTimeUpdate = "will be expelled from Dynamis in (\\d+) (minute|minutes|second|seconds)";
MessageMatch.AbysseaTime = "visitant status will wear off in (\\d+) (minute|minutes|second|seconds)"
MessageMatch.AbysseaRestLights1 = "Pearlescent: (\\d+) / Ebon: (\\d+)";
MessageMatch.AbysseaRestLights2 = "Golden: (\\d+) / Silvery: (\\d+)";
MessageMatch.AbysseaRestLights3 = "Azure: (\\d+) / Ruby: (\\d+) / Amber: (\\d+)";
MessageMatch.AbysseaLights = "body emits [a|an] (feeble|faint|mild|strong|instance) (pearlescent|golden|silvery|ebon|azure|ruby|amber) light!";
MessageMatch.AssaultObj = "Commencing (.*)(.*)!.*: (.*)[0|1]";
MessageMatch.AssaultTime = "You have (\\d+) (minute|minutes|second|seconds) .* to complete this mission";
MessageMatch.AssaultTimeUpdate = "Time remaining: (\\d+) (minute|minutes|second|seconds).*";