function CopyTable(t1, t2)
    for i,v in pairs(t1) do
        if (type(v) ~= "table") then
            t2[i] = v;
        else
            CopyTable(v, t2[i]);
        end
    end
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

function SeparateNumbers(val, sep)
    local separated = string.gsub(val, "(%d)(%d%d%d)$", "%1" .. sep .. "%2", 1)
    local found = 0;
    while true do
        separated, found = string.gsub(separated, "(%d)(%d%d%d),", "%1" .. sep .. "%2,", 1)
        if found == 0 then break end
    end
    return separated;
end