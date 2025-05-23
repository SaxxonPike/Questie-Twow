--[[
Name: Astrolabe
Revision: $Rev: 19 $
$Date: 2006-11-26 09:36:31 +0100 (So, 26 Nov 2006) $
Author(s): Esamynn (jcarrothers@gmail.com)
Inspired By: Gatherer by Norganna
             MapLibrary by Kristofer Karlsson (krka@kth.se)
Website: http://esamynn.wowinterface.com/
Documentation:
SVN:
Description:
    This is a library for the World of Warcraft UI system to place
    icons accurately on both the Minimap and the Worldmaps accurately
    and maintain the accuracy of those positions.

License:

Copyright (C) 2006  James Carrothers

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
]]

local LIBRARY_VERSION_MAJOR = "Astrolabe-0.2"
local LIBRARY_VERSION_MINOR = "$Revision: 19 $"
if not AceLibrary then error(LIBRARY_VERSION_MAJOR .. " requires AceLibrary.") end
if not AceLibrary:IsNewVersion(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR) then return end
Astrolabe = {};
WorldMapSize, MinimapSize = {}, {}
local initSizes
--------------------------------------------------------------------------------------------------------------
-- Working Tables and Config Constants
--------------------------------------------------------------------------------------------------------------
Astrolabe.LastPlayerPosition = {};
Astrolabe.MinimapIcons = {};
Astrolabe.MinimapUpdateTime = 0.2;
Astrolabe.UpdateTimer = 0.2;
Astrolabe.ForceNextUpdate = false;
Astrolabe.minimapOutside = false;
local twoPi = math.pi * 2;
--------------------------------------------------------------------------------------------------------------
-- General Uility Functions
--------------------------------------------------------------------------------------------------------------
local function getContPosition( zoneData, z, x, y )
    --Fixes nil error
    if z < 0 then
        z = 1;
    end
    --Fixes missing zoneData
    if zoneData == nil then
        return 0, 0; -- temporary fix, todo: log this
    end
    
    if ( z ~= 0 ) then
        zoneData = zoneData[z];
        x = x * zoneData.width + zoneData.xOffset;
        y = y * zoneData.height + zoneData.yOffset;
    else
        x = x * zoneData.width;
        y = y * zoneData.height;
    end
    return x, y;
end

function Astrolabe:ComputeDistance( c1, z1, x1, y1, c2, z2, x2, y2 )
    z1 = z1 or 0;
    z2 = z2 or 0;

    local dist, xDelta, yDelta;
    if ( c1 == c2 and z1 == z2 ) then
        -- points in the same zone
        local zoneData = WorldMapSize[c1];
        if ( z1 ~= 0 ) then
            zoneData = zoneData[z1];
        end
        if zoneData == nil then
            return 0, 0, 0; -- temporary fix, todo: log this
        end
        xDelta = (x2 - x1) * zoneData.width;
        yDelta = (y2 - y1) * zoneData.height;
    elseif ( c1 == c2 ) then
        -- points on the same continent
        local zoneData = WorldMapSize[c1];
        if zoneData == nil then
            return 0, 0, 0; -- temporary fix, todo: log this
        end
        x1, y1 = getContPosition(zoneData, z1, x1, y1);
        x2, y2 = getContPosition(zoneData, z2, x2, y2);
        xDelta = (x2 - x1);
        yDelta = (y2 - y1);
    elseif ( c1 and c2 ) then
        local cont1 = WorldMapSize[c1];
        local cont2 = WorldMapSize[c2];
        if cont1 == nil or cont2 == nil then
            return 0, 0, 0; -- temporary fix, todo: log this
        end
        if ( cont1.parentContinent == cont2.parentContinent ) then
            if ( c1 ~= cont1.parentContinent ) then
                x1, y1 = getContPosition(cont1, z1, x1, y1);
                x1 = x1 + cont1.xOffset;
                y1 = y1 + cont1.yOffset;
            end
            if ( c2 ~= cont2.parentContinent ) then
                x2, y2 = getContPosition(cont2, z2, x2, y2);
                x2 = x2 + cont2.xOffset;
                y2 = y2 + cont2.yOffset;
            end
            xDelta = (x2 or 0) - (x1 or 0); -- For Alliance in Ragefire Chasm on twow errors here without the "or 0" update.
            yDelta = (y2 or 0) - (y1 or 0); -- For Alliance in Ragefire Chasm on twow errors here without the "or 0" update.
        end
    end
    if ( xDelta and yDelta ) then
        dist = sqrt(xDelta*xDelta + yDelta*yDelta);
    end
    return dist, xDelta, yDelta;
end

function Astrolabe:TranslateWorldMapPosition( C, Z, xPos, yPos, nC, nZ )
    Z = Z or 0;
    nZ = nZ or 0;
    if ( nC < 0 ) then
        return;
    end
    --Fixes nil error.
    if(C < 0) then
        C=2;
    end
    if(nC < 0) then
        nC = 2;
    end
    local zoneData;
    if ( C == nC and Z == nZ ) then
        return xPos, yPos;
    elseif ( C == nC ) then
        -- points on the same continent
        zoneData = WorldMapSize[C];
        xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
        if ( nZ ~= 0 and zoneData[nZ] ~= nil) then
            zoneData = zoneData[nZ];
            xPos = xPos - zoneData.xOffset;
            yPos = yPos - zoneData.yOffset;
        end
    elseif (C and nC) and (WorldMapSize[C] and WorldMapSize[nC]) and (WorldMapSize[C].parentContinent == WorldMapSize[nC].parentContinent) then -- Entering RFC as an ally on twow this errored without the edit.
        -- different continents, same world
        zoneData = WorldMapSize[C];
        local parentContinent = zoneData.parentContinent;
        xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
        if ( C ~= parentContinent ) then
            -- translate up to world map if we aren't there already
            xPos = xPos + zoneData.xOffset;
            yPos = yPos + zoneData.yOffset;
            zoneData = WorldMapSize[parentContinent];
        end
        if ( nC ~= parentContinent ) then
            --translate down to the new continent
            zoneData = WorldMapSize[nC];
            xPos = xPos - zoneData.xOffset;
            yPos = yPos - zoneData.yOffset;
            if ( nZ ~= 0 and zoneData[nZ] ~= nil) then
                zoneData = zoneData[nZ];
                xPos = xPos - zoneData.xOffset;
                yPos = yPos - zoneData.yOffset;
            end
        end
    else
        return;
    end
    return (xPos / zoneData.width), (yPos / zoneData.height);
end

Astrolabe_LastX = 0;
Astrolabe_LastY = 0;
Astrolabe_LastZ = 0;
Astrolabe_LastC = 0;
function Astrolabe:GetCurrentPlayerPosition()
    local x, y = GetPlayerMapPosition("player")
    if (x <= 0 and y <= 0) then
        if not WorldMapFrame:IsVisible() then
            SetMapToCurrentZone()
            x, y = GetPlayerMapPosition("player")
            if (x <= 0 and y <= 0) then
                SetMapZoom(GetCurrentMapContinent())
                x, y = GetPlayerMapPosition("player")
                if (x <= 0 and y <= 0) then
                    return
                end
            end
        else
            return Astrolabe_LastC, Astrolabe_LastZ, Astrolabe_LastX, Astrolabe_LastY
        end
    end
    local C, Z = GetCurrentMapContinent(), GetCurrentMapZone()
    local playerCont, playerZone = C, Z
    if (playerZone == 0) then
        playerZone = Astrolabe_LastZ
    end
    if (playerCont == 0) then
        playerCont = Astrolabe_LastC
    end
    if (not WorldMapSize[playerCont]) then
        playerCont, playerZone = 0, 0
    end
    if (playerCont > 0 and not WorldMapSize[playerCont][playerZone]) then
        playerZone = 0
    end
    local nX, nY = self:TranslateWorldMapPosition(C, Z, x, y, playerCont, playerZone)
    Astrolabe_LastX = nX
    Astrolabe_LastY = nY
    Astrolabe_LastC = playerCont
    Astrolabe_LastZ = playerZone
    return Astrolabe_LastC, Astrolabe_LastZ, Astrolabe_LastX, Astrolabe_LastY;
end
--------------------------------------------------------------------------------------------------------------
-- Working Table Cache System
--------------------------------------------------------------------------------------------------------------
local tableCache = {};
tableCache["__mode"] = "v";
setmetatable(tableCache, tableCache);
local function GetWorkingTable( icon )
    if ( tableCache[icon] ) then
        return tableCache[icon];
    else
        local T = {};
        tableCache[icon] = T;
        return T;
    end
end
--------------------------------------------------------------------------------------------------------------
-- Minimap Icon Placement
--------------------------------------------------------------------------------------------------------------
function Astrolabe:PlaceIconOnMinimap( icon, continent, zone, xPos, yPos )
    -- check argument types
    self:argCheck(icon, 2, "table");
    self:assert(icon.SetPoint and icon.ClearAllPoints, "Usage Message");
    self:argCheck(continent, 3, "number");
    self:argCheck(zone, 4, "number", "nil");
    self:argCheck(xPos, 5, "number");
    self:argCheck(yPos, 6, "number");
    local lastPosition = self.LastPlayerPosition;
    local lC, lZ, lx, ly = lastPosition[1], lastPosition[2], lastPosition[3], lastPosition[4];
    if (not lC) or (not lZ) or (not lx) or (not ly) then
        lastPosition[1], lastPosition[2], lastPosition[3], lastPosition[4] = nil, nil, nil, nil;
        lastPosition[1], lastPosition[2], lastPosition[3], lastPosition[4] = Astrolabe:GetCurrentPlayerPosition();
        lC, lZ, lx, ly = lastPosition[1], lastPosition[2], lastPosition[3], lastPosition[4];
    end
    local dist, xDist, yDist = self:ComputeDistance(lC, lZ, lx, ly, continent, zone, xPos, yPos);
    if not ( dist ) then
        --icon's position has no meaningful position relative to the player's current location
        return -1;
    end
    local iconData = self.MinimapIcons[icon];
    if not ( iconData ) then
        iconData = GetWorkingTable(icon);
        self.MinimapIcons[icon] = iconData;
    end
    iconData.continent = continent;
    iconData.zone = zone;
    iconData.xPos = xPos;
    iconData.yPos = yPos;
    iconData.dist = dist;
    iconData.xDist = xDist;
    iconData.yDist = yDist;
    --show the new icon and force a placement update on the next screen draw
    icon:Show()
    self.ForceNextUpdate = true
    self.UpdateTimer = self.MinimapUpdateTime
    self:UpdateMinimapIconPositions();
    return 0;
end

function Astrolabe:RemoveIconFromMinimap( icon )
    if not ( self.MinimapIcons[icon] ) then
        return 1;
    end
    self.MinimapIcons[icon] = nil;
    icon:Hide();
    return 0;
end

function Astrolabe:RemoveAllMinimapIcons()
    local minimapIcons = self.MinimapIcons
    for k, v in pairs(minimapIcons) do
        minimapIcons[k] = nil;
        k:Hide();
    end
end

function Astrolabe:isMinimapInCity()
    local tempzoom = 0;
    self.minimapOutside = true;
    if (GetCVar("minimapZoom") == GetCVar("minimapInsideZoom")) then
        if (GetCVar("minimapInsideZoom")+0 >= 3) then
            Minimap:SetZoom(Minimap:GetZoom() - 1);
            tempzoom = 1;
        else
            Minimap:SetZoom(Minimap:GetZoom() + 1);
            tempzoom = -1;
        end
    end
    if (GetCVar("minimapInsideZoom")+0 == Minimap:GetZoom()) then self.minimapOutside = false; end
    Minimap:SetZoom(Minimap:GetZoom() + tempzoom);
end

local function placeIconOnMinimap( minimap, minimapZoom, mapWidth, mapHeight, icon, dist, xDist, yDist )
    local mapDiameter;
    if ( Astrolabe.minimapOutside ) then
        mapDiameter = MinimapSize.outdoor[minimapZoom];
    else
        mapDiameter = MinimapSize.indoor[minimapZoom];
    end
    local mapRadius = mapDiameter / 2;
    local xScale = mapDiameter / mapWidth;
    local yScale = mapDiameter / mapHeight;
    local iconDiameter = ((icon:GetWidth() / 2) -3) * xScale; -- LaYt +3
    icon:ClearAllPoints();
    local signx,signy =1,1;
    -- Adding square map support by LaYt
    if (Squeenix or (simpleMinimap_Skins and simpleMinimap_Skins:GetShape() == "square") or (pfUI and pfUI.minimap)) then
        if (xDist<0) then signx=-1; end
        if (yDist<0) then signy=-1; end
        if (math.abs(xDist) > (mapWidth/2*xScale) or math.abs(yDist) > (mapHeight/2*yScale)) then
            local xRatio,yRatio = 1,1;
            if ( yDist ~= 0 ) then
              xRatio = math.min( math.abs(xDist) / math.abs(yDist), 1 );
            end
            if ( xDist ~= 0 ) then
              yRatio = math.min( math.abs(yDist) / math.abs(xDist) , 1 );
            end
            xDist = (mapWidth/2*xScale - iconDiameter/2)*signx*xRatio;
            yDist = (mapHeight/2*yScale - iconDiameter/2)*signy*yRatio;
        end
    elseif ( (dist + iconDiameter) > mapRadius ) then
        -- position along the outside of the Minimap
        local factor = (mapRadius - iconDiameter) / dist;
        xDist = xDist * factor;
        yDist = yDist * factor;
    end
    icon:SetPoint("CENTER", minimap, "CENTER", xDist/xScale, -yDist/yScale);
end

local lastZoom;
function Astrolabe:UpdateMinimapIconPositions()
    local C, Z, x, y = self:GetCurrentPlayerPosition();
    if not ( C and Z and x and y ) then
        self.processingFrame:Hide();
    end
    local Minimap = Minimap;
    local lastPosition = self.LastPlayerPosition;
    local lC, lZ, lx, ly = lastPosition[1], lastPosition[2], lastPosition[3], lastPosition[4];
    local currentZoom = Minimap:GetZoom();
    local zoomChanged = lastZoom ~= Minimap:GetZoom()
    lastZoom = currentZoom;
    if zoomChanged then
        Astrolabe.MinimapUpdateTime = (6 - Minimap:GetZoom()) * 0.05
    end
    if ( (lC == C and lZ == Z and lx == x and ly == y)) then
        -- player has not moved since the last update
        if (zoomChanged or self.ForceNextUpdate ) then
            local mapWidth = Minimap:GetWidth();
            local mapHeight = Minimap:GetHeight();
            for icon, data in pairs(self.MinimapIcons) do
                placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, data.dist, data.xDist, data.yDist);
            end
            self.ForceNextUpdate = false;
        end
    else
        local dist, xDelta, yDelta = self:ComputeDistance(lC, lZ, lx, ly, C, Z, x, y);
        if not dist or not xDelta or not yDelta then return; end
        local mapWidth = Minimap:GetWidth();
        local mapHeight = Minimap:GetHeight();
        for icon, data in pairs(self.MinimapIcons) do
            local xDist = data.xDist - xDelta;
            local yDist = data.yDist - yDelta;
            local dist = sqrt(xDist*xDist + yDist*yDist);
            placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, dist, xDist, yDist);
            data.dist = dist;
            data.xDist = xDist;
            data.yDist = yDist;
        end
        lastPosition[1] = C;
        lastPosition[2] = Z;
        lastPosition[3] = x;
        lastPosition[4] = y;
    end
end

function Astrolabe:CalculateMinimapIconPositions()
    local C, Z, x, y = self:GetCurrentPlayerPosition();
    if not ( C and Z and x and y ) then
        self.processingFrame:Hide();
    end
    local currentZoom = Minimap:GetZoom();
    lastZoom = currentZoom;
    local Minimap = Minimap;
    local mapWidth = Minimap:GetWidth();
    local mapHeight = Minimap:GetHeight();
    for icon, data in pairs(self.MinimapIcons) do
        local dist, xDist, yDist = self:ComputeDistance(C, Z, x, y, data.continent, data.zone, data.xPos, data.yPos);
        placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, dist, xDist, yDist);
        data.dist = dist;
        data.xDist = xDist;
        data.yDist = yDist;
    end
    local lastPosition = self.LastPlayerPosition;
    lastPosition[1] = C;
    lastPosition[2] = Z;
    lastPosition[3] = x;
    lastPosition[4] = y;
end

function Astrolabe:GetDistanceToIcon( icon )
    local data = Astrolabe.MinimapIcons[icon];
    if ( data ) then
        return data.dist, data.xDist, data.yDist;
    end
end

function Astrolabe:GetDirectionToIcon( icon )
    local data = Astrolabe.MinimapIcons[icon];
    if ( data ) then
        local dir = atan2(data.xDist, -(data.yDist))
        if ( dir > 0 ) then
            return twoPi - dir;
        else
            return -dir;
        end
    end
end
--------------------------------------------------------------------------------------------------------------
-- World Map Icon Placement
--------------------------------------------------------------------------------------------------------------
function Astrolabe:PlaceIconOnWorldMap( worldMapFrame, icon, continent, zone, xPos, yPos )
    -- check argument types
    self:argCheck(worldMapFrame, 2, "table");
    self:assert(worldMapFrame.GetWidth and worldMapFrame.GetHeight, "Usage Message");
    self:argCheck(icon, 3, "table");
    self:assert(icon.SetPoint and icon.ClearAllPoints, "Usage Message");
    self:argCheck(continent, 4, "number");
    self:argCheck(zone, 5, "number", "nil");
    self:argCheck(xPos, 6, "number");
    self:argCheck(yPos, 7, "number");
    local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
    local nX, nY = self:TranslateWorldMapPosition(continent, zone, xPos, yPos, C, Z);
    if ( nX and nY and (0 < nX and nX <= 1) and (0 < nY and nY <= 1) ) then
        icon:ClearAllPoints();
        icon:SetPoint("CENTER", worldMapFrame, "TOPLEFT", nX * worldMapFrame:GetWidth(), -nY * worldMapFrame:GetHeight());
    end
    return nX, nY;
end
--------------------------------------------------------------------------------------------------------------
-- Handler Scripts
--------------------------------------------------------------------------------------------------------------
function Astrolabe:OnEvent( frame, event )
    if ( event == "MINIMAP_UPDATE_ZOOM" ) then
        Astrolabe:isMinimapInCity()
        -- re-calculate all Minimap Icon positions
        if ( frame:IsVisible() ) then
            self:CalculateMinimapIconPositions();
        end
    elseif ( event == "PLAYER_LEAVING_WORLD" ) then
        frame:Hide();
        self:RemoveAllMinimapIcons(); --dump all minimap icons
    elseif ( event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" ) then
        Astrolabe:isMinimapInCity()
        frame:Show();
    end
end

function Astrolabe:OnUpdate( frame, elapsed )
    local updateTimer = self.UpdateTimer - elapsed;
    if ( updateTimer > 0 ) then
        self.UpdateTimer = updateTimer;
        return;
    end
    self.UpdateTimer = self.MinimapUpdateTime;
    self:UpdateMinimapIconPositions();
end

function Astrolabe:OnShow( frame )
    self:CalculateMinimapIconPositions();
end
--------------------------------------------------------------------------------------------------------------
-- Library Registration
--------------------------------------------------------------------------------------------------------------
local function activate( self, oldLib, oldDeactivate )
    Astrolabe = self;
    local frame = self.processingFrame;
    if not ( frame ) then
        frame = CreateFrame("Frame");
        self.processingFrame = frame;
    end
    frame:SetParent("Minimap");
    frame:Hide();
    frame:UnregisterAllEvents();
    frame:RegisterEvent("MINIMAP_UPDATE_ZOOM");
    frame:RegisterEvent("PLAYER_LEAVING_WORLD");
    frame:RegisterEvent("PLAYER_ENTERING_WORLD");
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    frame:SetScript("OnEvent", function()
            self:OnEvent(this, event);
        end
    );
    frame:SetScript("OnUpdate",
        function( frame, elapsed )
            self:OnUpdate(frame, 1/GetFramerate());
        end
    );
    frame:SetScript("OnShow",
        function( frame )
            self:OnShow(frame);
        end
    );
    if not ( self.ContinentList ) then
        self.ContinentList = { GetMapContinents() };
        for C in pairs(self.ContinentList) do
            local zones = { GetMapZones(C) };
            self.ContinentList[C] = zones;
            for Z, N in ipairs(zones) do
                SetMapZoom(C, Z);
                zones[Z] = {mapFile = GetMapInfo(), mapName = N}
            end
        end
    end
    initSizes()
    frame:Show();
end
--------------------------------------------------------------------------------------------------------------
-- Data
--------------------------------------------------------------------------------------------------------------
-- diameter of the Minimap in game yards at
-- the various possible zoom levels
MinimapSize = {
    indoor = {
        [0] = 300, -- scale
        [1] = 240, -- 1.25
        [2] = 180, -- 5/3
        [3] = 120, -- 2.5
        [4] = 80,  -- 3.75
        [5] = 50,  -- 6
    },
    outdoor = {
        [0] = 466 + 2/3, -- scale
        [1] = 400,       -- 7/6
        [2] = 333 + 1/3, -- 1.4
        [3] = 266 + 2/6, -- 1.75
        [4] = 200,       -- 7/3
        [5] = 133 + 1/3, -- 3.5
    },
}
-- distances across and offsets of the world maps
-- in game yards
-- from classic client data, except for values commented on
local initDone = false
function initSizes()
    if initDone then return end
    initDone = true
    WorldMapSize = {
        -- World Map of Azeroth
        [0] = {
            parentContinent = 0,
            height = 29687.90575403711, -- as in Questie
            width = 44531.82907938571, -- as in Questie
        },
        -- Kalimdor
        [1] = {
            parentContinent = 0,
            height = 24533.2001953125,
            width = 36799.810546875,
            xOffset = -8310.0, -- as in Questie
            yOffset = 1815.0, -- as in Questie
            zoneData = {
                Ashenvale = {
                    height = 3843.75,
                    width = 5766.6665,
                    xOffset = 15366.6,
                    yOffset = 8126.984,
                },
                Aszhara = {
                    height = 3381.25,
                    width = 5070.833,
                    xOffset = 20343.684,
                    yOffset = 7458.234,
                },
                Barrens = {
                    height = 6756.25,
                    width = 10133.333,
                    xOffset = 14443.684,
                    yOffset = 11187.4,
                },
                Darkshore = {
                    height = 4366.6665,
                    width = 6550,
                    xOffset = 14124.934,
                    yOffset = 4466.5674,
                },
                Darnassis = {
                    height = 705.7295,
                    width = 1058.3333,
                    xOffset = 14128.236,
                    yOffset = 2561.584,
                },
                Desolace = {
                    height = 2997.9165,
                    width = 4495.833,
                    xOffset = 12833.267,
                    yOffset = 12347.817,
                },
                Durotar = {
                    height = 3525,
                    width = 5287.4995,
                    xOffset = 19029.1,
                    yOffset = 10991.567,
                },
                Dustwallow = {
                    height = 3499.9998,
                    width = 5250,
                    xOffset = 18041.6,
                    yOffset = 14833.233,
                },
                Felwood = {
                    height = 3833.3333,
                    width = 5749.9995,
                    xOffset = 15424.933,
                    yOffset = 5666.5674,
                },
                Feralas = {
                    height = 4633.333,
                    width = 6950,
                    xOffset = 11624.934,
                    yOffset = 15166.566,
                },
                Hyjal = {
                    height = 2831.2498,
                    width = 4245.8335,
                    xOffset = 17995.766,
                    yOffset = 6604.0674,
                },
                Moonglade = {
                    height = 1539.583,
                    width = 2308.3333,
                    xOffset = 18447.85,
                    yOffset = 4308.2344,
                },
                Mulgore = {
                    height = 3424.9998,
                    width = 5137.5,
                    xOffset = 15018.683,
                    yOffset = 13072.817,
                },
                Ogrimmar = {
                    height = 935.4166,
                    width = 1402.6045,
                    xOffset = 20747.201,
                    yOffset = 10526.023,
                },
                Silithus = {
                    height = 2322.916,
                    width = 3483.334,
                    xOffset = 14529.1,
                    yOffset = 18758.234,
                },
                StonetalonMountains = {
                    height = 3256.2498,
                    width = 4883.333,
                    xOffset = 13820.767,
                    yOffset = 9883.234,
                },
                Tanaris = {
                    height = 4600,
                    width = 6899.9995,
                    xOffset = 17285.35,
                    yOffset = 18674.9,
                },
                Teldrassil = {
                    height = 3393.75,
                    width = 5091.6665,
                    xOffset = 13252.017,
                    yOffset = 968.6504,
                },
                ThousandNeedles = {
                    height = 2933.333,
                    width = 4399.9995,
                    xOffset = 17499.934,
                    yOffset = 16766.566,
                },
                ThunderBluff = {
                    height = 695.8333,
                    width = 1043.75,
                    xOffset = 16549.934,
                    yOffset = 13649.9,
                },
                UngoroCrater = {
                    height = 2466.6665,
                    width = 3699.9998,
                    xOffset = 16533.266,
                    yOffset = 18766.566,
                },
                Winterspring = {
                    height = 4733.333,
                    width = 7100,
                    xOffset = 17383.266,
                    yOffset = 4266.5674,
                },
            },
        },
        -- Eastern Kingdoms
        [2] = {
            parentContinent = 0,
            height = 23466.60009765625,
            width = 35199.900390625,
            xOffset = 16625.0, -- guessed
            yOffset = 2470.0, -- guessed
            zoneData = {
                Alterac = {
                    height = 1866.6666,
                    width = 2800,
                    xOffset = 15216.667,
                    yOffset = 5966.6,
                },
                Arathi = {
                    height = 2400,
                    width = 3600,
                    xOffset = 16866.666,
                    yOffset = 7599.9336,
                },
                Badlands = {
                    height = 1658.3335,
                    width = 2487.5,
                    xOffset = 18079.166,
                    yOffset = 13356.184,
                },
                BlastedLands = {
                    height = 2233.334,
                    width = 3350,
                    xOffset = 17241.666,
                    yOffset = 18033.266,
                },
                BurningSteppes = {
                    height = 1952.0835,
                    width = 2929.1665,
                    xOffset = 16266.667,
                    yOffset = 14497.85,
                },
                DeadwindPass = {
                    height = 1666.667,
                    width = 2500,
                    xOffset = 16833.334,
                    yOffset = 17333.266,
                },
                DunMorogh = {
                    height = 3283.3333,
                    width = 4925,
                    xOffset = 14197.917,
                    yOffset = 11343.684,
                },
                Duskwood = {
                    height = 1800,
                    width = 2700,
                    xOffset = 15166.667,
                    yOffset = 17183.266,
                },
                EasternPlaguelands = {
                    height = 2581.2498,
                    width = 3870.8335,
                    xOffset = 18185.416,
                    yOffset = 3666.6003,
                },
                Elwynn = {
                    height = 2314.583,
                    width = 3470.8333,
                    xOffset = 14464.583,
                    yOffset = 15406.184,
                },
                Gillijim = {
                    height = 1927.3799,
                    width = 2464.9438,
                    xOffset = 11893.096,
                    yOffset = 20130.164,
                },
                Hilsbrad = {
                    height = 2133.3333,
                    width = 3200,
                    xOffset = 14933.333,
                    yOffset = 7066.6,
                },
                Hinterlands = {
                    height = 2566.6665,
                    width = 3850,
                    xOffset = 17575,
                    yOffset = 5999.9336,
                },
                Ironforge = {
                    height = 527.6045,
                    width = 790.62506,
                    xOffset = 16713.592,
                    yOffset = 12035.842,
                },
                Lapidis = {
                    height = 2042.8711,
                    width = 2165.0662,
                    xOffset = 11471.88,
                    yOffset = 18398.293,
                },
                LochModan = {
                    height = 1839.583,
                    width = 2758.333,
                    xOffset = 17993.75,
                    yOffset = 11954.1,
                },
                Redridge = {
                    height = 1447.916,
                    width = 2170.8333,
                    xOffset = 17570.834,
                    yOffset = 16041.6,
                },
                SearingGorge = {
                    height = 1487.4995,
                    width = 2231.2498,
                    xOffset = 16322.917,
                    yOffset = 13566.6,
                },
                Silverpine = {
                    height = 2800,
                    width = 4200,
                    xOffset = 12550,
                    yOffset = 5799.9336,
                },
                Stormwind = {
                    height = 1158.333,
                    width = 1737.5,
                    xOffset = 14277.083,
                    yOffset = 15462.434,
                },
                Stranglethorn = {
                    height = 4254.166,
                    width = 6381.25,
                    xOffset = 13779.167,
                    yOffset = 18635.35,
                },
                SwampOfSorrows = {
                    height = 1529.167,
                    width = 2293.75,
                    xOffset = 18222.916,
                    yOffset = 17087.434,
                },
                Tirisfal = {
                    height = 3012.4998,
                    width = 4518.75,
                    xOffset = 12966.667,
                    yOffset = 3629.1003,
                },
                Undercity = {
                    height = 640.1041,
                    width = 959.375,
                    xOffset = 15126.808,
                    yOffset = 5588.655,
                },
                WesternPlaguelands = {
                    height = 2866.6665,
                    width = 4300,
                    xOffset = 15583.333,
                    yOffset = 4099.9336,
                },
                Westfall = {
                    height = 2333.333,
                    width = 3499.9998,
                    xOffset = 12983.334,
                    yOffset = 16866.6,
                },
                Wetlands = {
                    height = 2756.25,
                    width = 4135.4165,
                    xOffset = 16389.584,
                    yOffset = 9614.517,
                },
            },
        },
        [3] = { -- todo: figure out wtf to use (we're just trying EK values for now)
            parentContinent = 0,
            height = 23466.60009765625,
            width = 35199.900390625,
            xOffset = 16625.0, -- guessed
            yOffset = 2470.0, -- guessed
            zoneData = {
                Collin = {
                    height = 25100.969,
                    width = 37651.453,
                    xOffset = -1279.8691,
                    yOffset = 4382.1035,
                },
                EversongWoods = {
                    height = 3283.333,
                    width = 4925,
                    xOffset = 20259.467,
                    yOffset = 2534.6875,
                },
                Ghostlands = {
                    height = 2199.9995,
                    width = 3300,
                    xOffset = 21055.3,
                    yOffset = 5309.6875,
                },
                SilvermoonCity = {
                    height = 806.7705,
                    width = 1211.4585,
                    xOffset = 22172.717,
                    yOffset = 3422.6445,
                },
            },        
        }
    }
    local zeroData = { xOffset = 0, height = 0, yOffset = 0, width = 0 };
    for continent, zones in pairs(Astrolabe.ContinentList) do
        local mapData = WorldMapSize[continent];
        
        -- some servers will have extra continents which this addon does not account for
        if (mapData == nil) then
            DEFAULT_CHAT_FRAME:AddMessage("Astrolabe is missing data for continent " .. continent .. ":");
            for index, zData in pairs(zones) do
                DEFAULT_CHAT_FRAME:AddMessage(zData);
            end
        else
            for index, zData in pairs(zones) do
                if (mapData.zoneData == nil) then
                    DEFAULT_CHAT_FRAME:AddMessage("Astrolabe is missing data for zone " .. index);
                    mapData.zoneData = {};
                else
                    if not ( mapData.zoneData[zData.mapFile] ) then
                    --WE HAVE A PROBLEM!!!
                    -- Disabled because TBC zones were removed
                    --ChatFrame1:AddMessage("Astrolabe is missing data for "..select(index, GetMapZones(continent))..".");
                        DEFAULT_CHAT_FRAME:AddMessage("Astrolabe is missing data for zone " .. zData.mapFile);
                        mapData.zoneData[zData.mapFile] = zeroData;
                    end
                    mapData[index] = mapData.zoneData[zData.mapFile];
                    mapData[index].mapName = zData.mapName
                    mapData.zoneData[zData.mapFile] = nil;
                end
            end
        end
    end
end

AceLibrary:Register(Astrolabe, LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR, activate)
