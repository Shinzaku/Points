HelpString = "\30\67- \30\71config\30\67 - Brings up the configuration window\n" ..
             "\30\67Check the configuration window for all available options\n" ..
             "\30\67If issues found, please submit an issue at:\n\30\92https://github.com/Shinzaku/Ashita4-Addons/points/";

DefaultColors = T{}
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

DefaultSettings = T{
    use_compact_ui = { false, },
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
    num_separator = "",
    bar_divider = "\xef\x85\x82",
    compact_divider = "|",
    token_order_default = "[XP] [Merits] [XPHour] [XPChain] [DIV] [CP] [JP] [JPHour] [CPChain] [DIV] [Sparks] [DIV] [Accolades] [DIV] [Gil]",
    token_order_mastered = "[EP] [EPHour] [EPChain] [DIV] [CP] [JP] [JPHour] [CPChain] [DIV] [Sparks] [DIV] [Accolades] [DIV] [Gil]",
    token_enabled_mastered = { true, },
    token_order_dynamis = "[DynamisKI] [DIV] [EventTimer]",
    token_enabled_dynamis = { true, },
    token_order_abyssea = "[Pearl] [Azure] [Ruby] [Amber] [Gold] [Silver] [Ebon] [DIV] [EventTimer]",
    token_enabled_abyssea = { true, },
    token_order_assault = "[AssaultObjective] [DIV] [EventTimer]",
    token_enabled_assault = { true, },
    token_order_nyzul = "[NyzulFloor] [DIV] [NyzulObjective] [DIV] [EventTimer]",
    token_enabled_nyzul = { true, },
    token_order_voidwatch = "[VWRed] [VWBlue] [VWGreen] [VWYellow] [VWWhite]",
    token_enabled_voidwatch = { true, },
    theme = "default",
    rate_reset_timer = 600,
    colors = { mainText = { 1.0, 1.0, 1.0, 1.0 }, cappedValue = DefaultColors.FFXICappedValue, chainTimer = DefaultColors.FFXIYellow, bg = DefaultColors.FFXIGreyBg, bgBorder = DefaultColors.FFXIGreyBorder },
    use_job_icon = { true, },
    use_pbar_ascii = { false, },
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
TemplateChain = "%s#>%s (%s)";
TemplatePlain = "%s: %s";
TemplateTimer = "%02d:%02d:%02d";
TemplateRatio = "%s: %s/%s";

DynamisExtensionOrig = T{ 600, 600, 600, 900, 900 };
DynamisExtensionDream = T{ 600, 600, 600, 600, 1200 };
DynamisMapping = T{ [134] = DynamisExtensionOrig, [135] = DynamisExtensionOrig,
                   [185] = DynamisExtensionOrig, [186] = DynamisExtensionOrig, [187] = DynamisExtensionOrig, [188] = DynamisExtensionOrig,
                   [39] = DynamisExtensionDream, [40] = DynamisExtensionDream, [41] = DynamisExtensionDream, [42] = DynamisExtensionDream };
AbysseaMapping = T{ [15] = "Konschtat", [45] = "Tahrongi", [132] = "La Theine", [215] = "Attohwa", [216] = "Misareaux", [217] = "Vunkerl", [218] = "Altepa",
                    [253] = "Uleguerand", [254] = "Garuberg", [255] = "Empyreal Paradox", };
AbysseaLightEstimates = { ["pearlescent"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 230 },
                        ["golden"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 200 },
                        ["silvery"] = { ["feeble"] = 0, ["faint"] = 5, ["mild"] = 10, ["strong"] = 15, ["intense"] = 0, ["max"] = 200 },
                        ["ebon"] = { ["feeble"] = 0, ["faint"] = 1, ["mild"] = 2, ["strong"] = 3, ["intense"] = 0, ["max"] = 200 },
                        ["azure"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 },
                        ["ruby"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 },
                        ["amber"] = { ["feeble"] = 8, ["faint"] = 16, ["mild"] = 24, ["strong"] = 32, ["intense"] = 64, ["max"] = 255 }, };
AssaultMapping = T{ [69] = "Leujaoam Sanctum", [66] = "Mamool Ja Training Grounds", [63] = "Lebros Cavern", [56] = "Periqia", [55] = "Ilrusi Atoll" };
NyzulMapping = T{ [77] = "Nyzul Isle" };

MessageMatch = T{};
MessageMatch.ObtainedKI = "Obtained key item: \x1E\x03(.*)\x1E\x01";
MessageMatch.DynaTimeEntry = "(\\d+) minutes .* remaining in Dynamis";
MessageMatch.DynaTimeUpdate = "will be expelled from Dynamis in (\\d+) (minute|minutes|second|seconds)";
MessageMatch.AbysseaTime = "visitant status will wear off in (\\d+) (minute|minutes|second|seconds)"
MessageMatch.AbysseaRestLights1 = "Pearlescent: (\\d+) / Ebon: (\\d+).*Golden: (\\d+) / Silvery: (\\d+)";
MessageMatch.AbysseaRestLights2 = "Azure: (\\d+) / Ruby: (\\d+) / Amber: (\\d+)";
MessageMatch.AbysseaLights = "body emits [a|an] (feeble|faint|mild|strong|instance) (pearlescent|golden|silvery|ebon|azure|ruby|amber) light!";
MessageMatch.AssaultObj = "Commencing (.*)(.*)!.*: (.*)[0|1]";
MessageMatch.AssaultTime = "You have (\\d+) (minute|minutes|second|seconds).*to complete this mission";
MessageMatch.AssaultTimeUpdate = "Time remaining: (\\d+) (minute|minutes|second|seconds).*";
MessageMatch.NyzulObj = "Objective: (.*)[0|1]";
MessageMatch.NyzulFloor = "Transfer complete. Welcome to Floor (\\d+).*";

XPChainTimers = T{
    { lvl=10, maxtime={ 80, 80, 60, 40, 30, 15, }, },
    { lvl=20, maxtime={ 130, 130, 110, 80, 60, 25, }, },
    { lvl=30, maxtime={ 160, 150, 120, 90, 60, 30, }, },
    { lvl=40, maxtime={ 200, 200, 170, 130, 80, 40, }, },
    { lvl=50, maxtime={ 290, 290, 230, 170, 110, 50, }, },
    { lvl=99, maxtime={ 300, 300, 240, 180, 120, 60, }, },
}

AvailableTokens = T{
    { key="[XP]", desc="Current job's exp; Switches to LP once level 99" },
    { key="[Merits]", desc="Current job's merit points" },
    { key="[XPHour]", desc="Estimated EXP or merit points per hour" },
    { key="[XPChain]", desc="Current EXP or Limit chain with estimated timer" },
    { key="[CP]", desc="Current job's Capacity Points" },
    { key="[JP]", desc="Current job's Job Points" },
    { key="[JPHour]", desc="Estimated Job Points per hour" },
    { key="[CPChain]", desc="Current CP chain with estimated timer" },
    { key="[Sparks]", desc="" },
    { key="[Accolades]", desc="" },
    { key="[EP]", desc="Current job's Exemplary Points" },
    { key="[EPHour]", desc="Estimated EP per hour" },
    { key="[EPChain]", desc="Current EP chain with estimated timer" },
    { key="[DynamisKI]", desc="Trackers for time extension key items in Dynamis" },
    { key="[Pearl]", desc="" },
    { key="[Azure]", desc="" },
    { key="[Ruby]", desc="" },
    { key="[Amber]", desc="" },
    { key="[Gold]", desc="" },
    { key="[Silver]", desc="" },
    { key="[Ebon]", desc="" },
    { key="[AssaultObjective]", desc="" },
    { key="[EventTimer]", desc="" },
    { key="[Gil]", desc="" },
    { key="[Inv]", desc="Current space ratio in Gobbiebag (base inventory)" },
    { key="[DIV]", desc="Divider; Add to create space between tokens" }
}