type cvar3 = {}

interface engine {
	LightStyle = function(number, string): nil
}

interface hook {
	Remove = (function(string, string): nil)
	Add = (function(string, string, function): nil)
}

interface player {
	GetBots = function(): {}
}

interface all {
	ReplicateData = function(table, string, string): nil
	Cexec = function(table, string, string | nil): nil
}

interface Entity {
	Fire = function(self, string, string): nil
}

type ConVar = {}
type Texture = {}
interface MaterialObject {
	IsError = function(self): boolean
	GetTexture = function(self, string): Texture
}

type check = function(any, string): nil
type Material = function(string): MaterialObject
type GetConVarString = function(string): ConVar

type timer = {
	Simple = (function(number, function): nil),
	Remove = (function(string): nil),
}

type fog = Entity
type materials = nil


if SERVER then
	engine.LightStyle(0, "d")
	hook.Remove("PlayerFootstep", "snow")


	if not next(player.GetBots()) and pcall(require,"cvar3") then
		require("cvar3")
		all:ReplicateData("sv_cheats", "1")
		all:Cexec("mat_drawwater 0")
		all:Cexec("fog_enable_water_fog 0")
		--all:Cexec("r_3dsky 0")
	end


	fog:Fire("SetMaxDensity", "0")
	return
end

timer.Simple(1, function()render.RedownloadAllLightmaps() end)

timer.Remove("snow_sector_think")
hook.Remove("Think", "snow")

module 	( "ms" , package.seeall )

local replace = {["gm_construct/grass1"]=true,["models/mspropp/flatgrass"]=true,
["gm_construct/grass-sand_13"]=true,
["gm_construct/grass-rock"]=true,
["gm_construct/flatgrass_2"]=true,
["gm_construct/flatgrass"]=true,
["gm_construct/grass-sand"]=true,["gm_construct/grass-sand_13"]=true,
["gm_construct/grass-sand"]=true,
["gm_construct/grass-rock"]=true,
["gm_construct/flatgrass"]=true,
["gm_construct/grass"]=true,
["gm_construct/grass-sand"]=true,
["gm_construct/grass"]=true,
["models/mspropp/flatgrass"]=true,
["gm_construct/grass_13"]=true,
["gm_construct/grass"]=true,
	["concrete/prodflre"] = true,
	["nature/blendtoxictoxic004a"] = true,
	["de_cbble/grassfloor01"] = true,
	["METASTRUCT_2/GRASS"] = true,
	["GM_CONSTRUCT/GRASS"] = true,
	["nature/grassfloor002a"] = true,
	["nature/blendgrassgravel001a"] = true,
	["metastruct_2/blendgrass"] = true,
	["shadertest/seamless7"] = true,
	["nature/blenddirtgrass008b_lowfriction"] = true,
	["metastruct_2/blend_mud_rock"] = true,
	["nature/blenddirtgrass005a"] = true,
	["nature/blendsandgrass008a"] = true,
	["nature/red_grass"] = true,
	["nature/red_grass"] = true,
	["metastruct_2/blendg"] = true,
	["gm_construct/grass-sand"] = true,
	["nature/grassfloor002a_replacement"] = true,
	["nature/blendgrassgrass001a"] = true,
	["nature/blendsandgr"] = true,
	["nature/blendgroundtograss008"] = true,
	["maps/gm_construct_flatgrass_v6-2/gm_construct/grass_13_wvt_patch"] = true,
	["gm_construct/grass"] = true,
	["gm_construct/grass_13"] = true,
	["gm_construct/grass-sand_133"] = true,
	["maxofs2d/grass_02"]=true,
	["custom/grasssandblend08"] = true,
	["custom/grasssandblend09"] = true,
	["maps/gm_bluehills/custom/grasssandblend08_wvt_patch"] = true,
	["maps/gm_bluehills/custom/grasssandblend09_wvt_patch"] = true,
	["maxofs2d/grass_01"]=true,["phoenix_storms/ps_grass"]=true,
--[[ 	["maps/metastruct_2/metastruct_2/road_6120_8680_-12944"] = true,
	["maps/metastruct_2/metastruct_2/road_-3656_12928_-13216"] = true,
	["maps/metastruct_2/metastruct_2/road_-6332_11456_-13184"] = true,
	["CONCRETE/CONCRETEFLOOR001A"] = true,
	["maps/metastruct_2/tile/tileroof004b_-13744_12784_-13200"] = true,
	["maps/metastruct_2/tile/tileroof004a_-14224_11856_-13216"] = true,
	["maps/metastruct_2/tile/tileroof004a_-14192_12176_-12784"] = true,
	["maps/metastruct_2/metastruct_2/road_-13008_12656_-13104"] = true,




	["maps/metastruct_2/tile/tileroof004a_6120_8680_-12944"] = true,
	["maps/metastruct_2/tile/tileroof004b_-14192_12176_-12784"] = true,
	["maps/metastruct_2/tile/tileroof004b_-9035_13056_-13188"] = true,
	["maps/metastruct_2/metastruct_2/road_-9035_13056_-13188"] = true,
	["maps/metastruct_2/tile/tileroof004a_-6332_11456_-13184"] = true,
	["maps/metastruct_2/tile/tileroof004b_6120_8680_-12944"] = true,	 ]]


}

do
materials = materials or {} local self = materials


materials.Replaced = materials.Replaced or {}

function materials.ReplaceTexture(path, to)
	check(path, "string")
	check(to, "string", "ITexture", "Material")

	path = path:lower()

	local mat = Material(path)

	if not mat:IsError() then

		local typ = type(to)
		local tex

		if typ == "string" then
			tex = Material(to):GetTexture("$basetexture")
		elseif typ == "ITexture" then
			tex = to
		elseif typ == "Material" then
			tex = to:GetTexture("$basetexture")
		else return false end

		self.Replaced[path] = self.Replaced[path] or {}

		self.Replaced[path].OldTexture = self.Replaced[path].OldTexture or mat:GetTexture("$basetexture")
		self.Replaced[path].NewTexture = tex
mat:SetTexture("$basetexture2",tex)
		mat:SetTexture("$basetexture",tex)

		return true
	end

	return false
end


function materials.SetColor(path, color)
	check(path, "string")
	check(color, "Vector")

	path = path:lower()

	local mat = Material(path)

	if not mat:IsError() then
		self.Replaced[path] = self.Replaced[path] or {}
		self.Replaced[path].OldColor = self.Replaced[path].OldColor or mat:GetVector("$color")
		self.Replaced[path].NewColor = color

		mat:SetVector("$color", color)

		return true
	end

	return false
end


function materials.RestoreAll()
	for name, tbl in pairs(self.Replaced) do
		if not pcall(function()
				if tbl.OldTexture then
					materials.ReplaceTexture(name, tbl.OldTexture)
				end

				if tbl.OldColor then
					materials.SetColor(name, tbl.OldColor)
				end
			end)
		then
			print("Failed to restore: " .. tostring(name))
		end
	end
end
hook.Add('ShutDown','MatRestorer',materials.RestoreAll)

--if not ms then

	-- Material Extensions / SkyBox modder
	local sky =
	{
		["up"]=true,
		["dn"]=true,
		["lf"]=true,
		["rt"]=true,
		["ft"]=true,
		["bk"]=true,
	}

	local sky_name = GetConVarString("sv_skyname")

	for side, path in pairs(sky) do
		path = "skybox/" .. sky_name .. side
		materials.ReplaceTexture(path, "Decals/decal_paintsplatterpink001")
		materials.SetColor(path, Vector(0.9,1,0.9)*0.1)
	end

	end
--end


for k,v in pairs(replace) do
	materials.ReplaceTexture(k, "Nature/blendsandsand008a.vmt")
	materials.SetColor(k, Vector(1, 1, 1)*(ms and 0.6 or 0.7))
end

if CLIENT then

	hook.Add("RenderScreenspaceEffects", "hm", function()
		--DrawToyTown( 2, 200)

		local tbl = {}
			tbl[ "$pp_colour_addr" ] = 0.035
			tbl[ "$pp_colour_addg" ] = 0.015
			tbl[ "$pp_colour_addb" ] = 0
			tbl[ "$pp_colour_brightness" ] = 0
			tbl[ "$pp_colour_contrast" ] = 1
			tbl[ "$pp_colour_colour" ] = 1.2
			tbl[ "$pp_colour_mulr" ] = 0
			tbl[ "$pp_colour_mulg" ] = 0
			tbl[ "$pp_colour_mulb" ] = 0
		DrawColorModify( tbl )

	end)

	local function SetupFog()
		render.FogMode(1)
		render.FogStart(0)
		render.FogEnd(4096*4)
		render.FogColor(255, 100, 100)
		render.FogMaxDensity(0.05)

		return true
	end

	hook.Add("SetupWorldFog", "desert", SetupFog)
	hook.Add("SetupSkyboxFog", "desert", SetupFog)


end