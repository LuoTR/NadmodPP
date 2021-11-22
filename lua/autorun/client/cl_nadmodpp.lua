-- =================================
-- NADMOD PP - Prop Protection
-- By Nebual@nebtown.info 2012
-- Menus designed after SpaceTech's Simple Prop Protection
-- =================================
if !NADMOD then 
	NADMOD = {}
	NADMOD.PropOwners = {}
	NADMOD.PropNames = {}
	NADMOD.PPConfig = {}
	NADMOD.Friends = {}
end

local Props = NADMOD.PropOwners
local PropNames = NADMOD.PropNames
net.Receive("nadmod_propowners",function(len)
	local nameMap = {}
	for i=1, net.ReadUInt(8) do
		nameMap[i] = {SteamID = net.ReadString(), Name = net.ReadString()}
	end
	for i=1, net.ReadUInt(32) do
		local id, owner = net.ReadUInt(16), nameMap[net.ReadUInt(8)]
		if owner.SteamID == "-" then Props[id] = nil PropNames[id] = nil
		elseif owner.SteamID == "W" then PropNames[id] = "世界"
		elseif owner.SteamID == "O" then PropNames[id] = "无拥有者"
		else
			Props[id] = owner.SteamID
			PropNames[id] = owner.Name
		end
	end
end)

function NADMOD.GetPropOwner(ent)
	local id = Props[ent:EntIndex()]
	return id and player.GetBySteamID(id)
end

function NADMOD.PlayerCanTouch(ply, ent)
	-- If PP is off or the ent is worldspawn, let them touch it
	if not tobool(NADMOD.PPConfig["toggle"]) then return true end
	if ent:IsWorld() then return ent:GetClass()=="worldspawn" end
	if !IsValid(ent) or !IsValid(ply) or ent:IsPlayer() or !ply:IsPlayer() then return false end

	local index = ent:EntIndex()
	if not Props[index] then
		return false
	end

	-- Ownerless props can be touched by all
	if PropNames[index] == "无拥有者" then return true end 
	-- Admins can touch anyones props + world
	if NADMOD.PPConfig["adminall"] and NADMOD.IsPPAdmin(ply) then return true end
	-- Players can touch their own props
	local plySteam = ply:SteamID()
	if Props[index] == plySteam then return true end
	-- Friends can touch LocalPlayer()'s props
	if Props[index] == LocalPlayer():SteamID() and NADMOD.Friends[plySteam] then return true end

	return false
end

-- Does your admin mod not seem to work with Nadmod PP? Try overriding this function!
function NADMOD.IsPPAdmin(ply)
	if NADMOD.HasPermission then
		return NADMOD.HasPermission(ply, "PP_All")
	else
		-- If the admin mod NADMOD isn't present, just default to using IsAdmin
		return ply:IsAdmin()
	end
end

local nadmod_overlay_convar = CreateConVar("nadmod_overlay", 2, {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "0 - Disables NPP Overlay. 1 - Minimal overlay of just owner info. 2 - Includes model, entityID, class")
local font = "ChatFont"
hook.Add("HUDPaint", "NADMOD.HUDPaint", function()
	local nadmod_overlay_setting = nadmod_overlay_convar:GetInt()
	if nadmod_overlay_setting == 0 then return end
	local tr = LocalPlayer():GetEyeTrace()
	if !tr.HitNonWorld then return end
	local ent = tr.Entity
	if ent:IsValid() && !ent:IsPlayer() then
		local text = "拥有者: " .. (PropNames[ent:EntIndex()] or "未知")
		surface.SetFont(font)
		local Width, Height = surface.GetTextSize(text)
		local boxWidth = Width + 25
		local boxHeight = Height + 16
		if nadmod_overlay_setting > 1 then
			local text2 = "'"..string.sub(table.remove(string.Explode("/", ent:GetModel() or "?")), 1,-5).."' ["..ent:EntIndex().."]"
			local text3 = ent:GetClass()
			local w2,h2 = surface.GetTextSize(text2)
			local w3,h3 = surface.GetTextSize(text3)
			boxWidth = math.Max(Width,w2,w3) + 25
			boxHeight = boxHeight + h2 + h3
			draw.RoundedBox(4, ScrW() - (boxWidth + 4), (ScrH()/2 - 200) - 16, boxWidth, boxHeight, Color(0, 0, 0, 150))
			draw.SimpleText(text, font, ScrW() - (Width / 2) - 20, ScrH()/2 - 200, Color(255, 255, 255, 255), 1, 1)
			draw.SimpleText(text2, font, ScrW() - (w2 / 2) - 20, ScrH()/2 - 200 + Height, Color(255, 255, 255, 255), 1, 1)
			draw.SimpleText(text3, font, ScrW() - (w3 / 2) - 20, ScrH()/2 - 200 + Height + h2, Color(255, 255, 255, 255), 1, 1)
		else
			draw.RoundedBox(4, ScrW() - (boxWidth + 4), (ScrH()/2 - 200) - 16, boxWidth, boxHeight, Color(0, 0, 0, 150))
			draw.SimpleText(text, font, ScrW() - (Width / 2) - 20, ScrH()/2 - 200, Color(255, 255, 255, 255), 1, 1)
		end
	end
end)

function NADMOD.CleanCLRagdolls()
	for k,v in pairs(ents.FindByClass("class C_ClientRagdoll")) do v:SetNoDraw(true) end
	for k,v in pairs(ents.FindByClass("class C_BaseAnimating")) do v:SetNoDraw(true) end
end
net.Receive("nadmod_cleanclragdolls", NADMOD.CleanCLRagdolls)

-- =============================
-- NADMOD PP CPanels
-- =============================
net.Receive("nadmod_ppconfig",function(len)
	NADMOD.PPConfig = net.ReadTable()
	for k,v in pairs(NADMOD.PPConfig) do
		local val = v
		if isbool(v) then val = v and "1" or "0" end
		
		CreateClientConVar("npp_"..k,val, false, false)
		RunConsoleCommand("npp_"..k,val)
	end
	NADMOD.AdminPanel(NADMOD.AdminCPanel, true)
end)

concommand.Add("npp_apply",function(ply,cmd,args)
	for k,v in pairs(NADMOD.PPConfig) do
		if isbool(v) then NADMOD.PPConfig[k] = GetConVar("npp_"..k):GetBool()
		elseif isnumber(v) then NADMOD.PPConfig[k] = GetConVarNumber("npp_"..k)
		else NADMOD.PPConfig[k] = GetConVarString("npp_"..k)
		end
	end
	net.Start("nadmod_ppconfig")
		net.WriteTable(NADMOD.PPConfig)
	net.SendToServer()
end)

function NADMOD.AdminPanel(Panel, runByNetReceive)
	if Panel then
		if !NADMOD.AdminCPanel then NADMOD.AdminCPanel = Panel end
	end
	Panel:ClearControls()

	local nonadmin_help = Panel:Help("")
	nonadmin_help:SetAutoStretchVertical(false)
	if not runByNetReceive then 
		RunConsoleCommand("npp_refreshconfig")
		timer.Create("NADMOD.AdminPanelCheckFail",0.75,1,function()
			nonadmin_help:SetText("等待服务器表明你是管理员...")
		end)
		if not NADMOD.PPConfig then
			return
		end
	else
		timer.Remove("NADMOD.AdminPanelCheckFail")
	end
	Panel:SetName("NADMOD PP管理员面板")
	
	Panel:CheckBox(	"主物品保护开关", "npp_toggle")
	Panel:CheckBox(	"管理员能碰任何东西", "npp_adminall")
	local use_protection = Panel:CheckBox(	"启用E键保护", "npp_use")
	use_protection:SetToolTip("阻止非好友进入载具、按按钮和开门")
	
	local txt = Panel:Help("自动清除已断开玩家物品？")
	txt:SetAutoStretchVertical(false)
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	local autoclean_admins = Panel:CheckBox(	"自动清除管理员物品", "npp_autocdpadmins")
	autoclean_admins:SetToolTip("是否应该一并清除已断开管理员的物品？")
	local autoclean_timer = Panel:NumSlider("自动清除倒计时", "npp_autocdp", 0, 1200, 0 )
	autoclean_timer:SetToolTip("0 disables autocleaning")
	Panel:Button(	"应用设置", "npp_apply") 
	
	local txt = Panel:Help("                     清除面板")
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SetFont("DermaDefaultBold")
	txt:SetAutoStretchVertical(false)
	
	local counts = {}
	for k,v in pairs(NADMOD.PropOwners) do 
		counts[v] = (counts[v] or 0) + 1 
	end
	local dccount = 0
	for k,v in pairs(counts) do
		if k != "世界" and k != "无拥有者" then dccount = dccount + v end
	end
	for k, ply in pairs(player.GetAll()) do
		if IsValid(ply) then
			local steamid = ply:SteamID()
			Panel:Button( ply:Nick().." ("..(counts[steamid] or 0)..")", "nadmod_cleanupprops", ply:EntIndex() ) 
			dccount = dccount - (counts[steamid] or 0)
		end
	end
	
	Panel:Help(""):SetAutoStretchVertical(false) -- Spacer
	Panel:Button("清除已断开玩家的物品 (共"..dccount.."个)", "nadmod_cdp")
	Panel:Button("清除所有NPC", 			"nadmod_cleanclass", "npc_*")
	Panel:Button("清除所有布娃娃", 		"nadmod_cleanclass", "prop_ragdol*")
	Panel:Button("清除客户端布娃娃", "nadmod_cleanclragdolls")
	Panel:Button("清除世界上的绳子", "nadmod_cleanworldropes")
end

local metaply = FindMetaTable("Player")
local metaent = FindMetaTable("Entity")

-- Wrapper function as Bots return nothing clientside for their SteamID64
function metaply:SteamID64bot()
	if( not IsValid( self ) ) then return end
	if self:IsBot() then
		-- Calculate Bot's SteamID64 according to gmod wiki
		return  ( 90071996842377216 + tonumber( string.sub( self:Nick(), 4) ) -1 )
	else
		return self:SteamID64()
	end
end

net.Receive("nadmod_ppfriends",function(len)
	NADMOD.Friends = net.ReadTable()
	for _,tar in pairs(player.GetAll()) do
		CreateClientConVar("npp_friend_"..tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0", false, false)
		RunConsoleCommand("npp_friend_"..tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0")
	end
end)

concommand.Add("npp_applyfriends",function(ply,cmd,args)
	for _,tar in pairs(player.GetAll()) do
		NADMOD.Friends[tar:SteamID()] = GetConVar("npp_friend_"..tar:SteamID64bot()):GetBool()
	end
	net.Start("nadmod_ppfriends")
		net.WriteTable(NADMOD.Friends)
	net.SendToServer()
end)

function NADMOD.ClientPanel(Panel)
	RunConsoleCommand("npp_refreshfriends")
	Panel:ClearControls()
	if !NADMOD.ClientCPanel then NADMOD.ClientCPanel = Panel end
	Panel:SetName("NADMOD - 客户端面板")
	
	Panel:Button("清除物品", "nadmod_cleanupprops")
	Panel:Button("清除客户端布娃娃", "nadmod_cleanclragdolls")
	
	local txt = Panel:Help("                     好友面板")
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SetFont("DermaDefaultBold")
	txt:SetAutoStretchVertical(false)
	
	local Players = player.GetAll()
	if(table.Count(Players) == 1) then
		Panel:Help("没有别的玩家在线")
	else
		for _, tar in pairs(Players) do
			if(IsValid(tar) and tar != LocalPlayer()) then
				Panel:CheckBox(tar:Nick(), "npp_friend_"..tar:SteamID64bot())
			end
		end
		Panel:Button("应用好友列表", "npp_applyfriends")
	end
end

function NADMOD.SpawnMenuOpen()
	if NADMOD.AdminCPanel then
		NADMOD.AdminPanel(NADMOD.AdminCPanel)
	end
	if NADMOD.ClientCPanel then
		NADMOD.ClientPanel(NADMOD.ClientCPanel)
	end
end
hook.Add("SpawnMenuOpen", "NADMOD.SpawnMenuOpen", NADMOD.SpawnMenuOpen)

function NADMOD.PopulateToolMenu()
	spawnmenu.AddToolMenuOption("杂项", "NADMOD 物品保护", "Admin", "管理员", "", "", NADMOD.AdminPanel)
	spawnmenu.AddToolMenuOption("杂项", "NADMOD 物品保护", "Client", "客户端", "", "", NADMOD.ClientPanel)
end
hook.Add("PopulateToolMenu", "NADMOD.PopulateToolMenu", NADMOD.PopulateToolMenu)

net.Receive("nadmod_notify", function(len)
	local text = net.ReadString()
	notification.AddLegacy(text, NOTIFY_GENERIC, 5)
	surface.PlaySound("ambient/water/drip"..math.random(1, 4)..".wav")
	print(text)
end)

CPPI = {}

function CPPI:GetName() return "Nadmod物品保护" end
function CPPI:GetVersion() return "" end
function metaply:CPPIGetFriends() return {} end
function metaent:CPPIGetOwner() return NADMOD.GetPropOwner(self) end
function metaent:CPPICanTool(ply,mode) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPhysgun(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPickup(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPunt(ply) return NADMOD.PlayerCanTouch(ply,self) end
