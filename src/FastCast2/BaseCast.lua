--[[
	- Author : Mawin CK
	- Date : 2025
]]
-- Services
local HTTPS = game:GetService("HttpService")

-- Requires
local FastCastM = script.Parent
local TypeDef = require(FastCastM:WaitForChild("TypeDefinitions"))
local Signal = require(FastCastM:WaitForChild("Signal"))
local ActiveCast = require(FastCastM:WaitForChild("ActiveCast"))
local ActiveBlockcast = require(FastCastM:WaitForChild("ActiveBlockcast"))
--local ObjectCache = require(FastCastM:WaitForChild("ObjectCache"))

-- BaseCast
local BaseCast = {}
BaseCast.__index = BaseCast
BaseCast.__type = "BaseCast"

-- Public functions

function BaseCast.Init(BindableOutput : BindableEvent, Data : any)
	local self = setmetatable({}, BaseCast)
	-- Others
	--print(BindableOutput.Parent)
	self.Actor = BindableOutput.Parent
	self.Actives = setmetatable({}, {__mode = 'v'})
	-- Bindable
	self.Output = BindableOutput
	
	local BindableCleaner = Instance.new("BindableEvent")
	BindableCleaner.Name = "ActiveCastDestroyer"
	BindableCleaner.Parent = self.Actor
	
	if Data.useObjectCache then
		local BindableObjectCache = Instance.new("BindableFunction")
		BindableObjectCache.Parent = self.Actor
		BindableObjectCache.Name = "ActiveCastObjectCache"
		self.ObjectCache = BindableObjectCache
		self.CacheHolder = Data.CacheHolder
	end
	
	self.ActiveCastCleaner = BindableCleaner
	
	self.ActiveCastCleaner.Event:Connect(function(activeCastID : string)
		if self.Actives[activeCastID] then
			--print("CLEANED ACTIVECAST : " .. activeCastID)
			self.Actives[activeCastID] = nil
			self.Actor:SetAttribute("Tasks", self.Actor:GetAttribute("Tasks")-1)
		end
	end)
	
	return self
end

function BaseCast:Raycast(
	Origin : Vector3, 
	Direction : Vector3, 
	Velocity : Vector3 | number, 
	Behavior : TypeDef.FastCastBehavior
)
	--table.insert(self.Actives, ActiveCast.new(self, Origin, Direction, Velocity, Behavior))
	self.Actor:SetAttribute("Tasks", self.Actor:GetAttribute("Tasks")+1)
	
	local activeCastID = HTTPS:GenerateGUID(false)
	self.Actives[activeCastID] = ActiveCast.new({
		Output = self.Output,
		ActiveCastCleaner = self.ActiveCastCleaner,
		ObjectCache = self.ObjectCache
	}, activeCastID, Origin, Direction, Velocity, Behavior)
end

function BaseCast:Blockcast(
	Origin : Vector3,
	Size : Vector3, 
	Direction : Vector3,
	Velocity : Vector3 | number,
	Behavior : TypeDef.FastCastBehavior
)
	self.Actor:SetAttribute("Tasks", self.Actor:GetAttribute("Tasks")+1)

	local activeCastID = HTTPS:GenerateGUID(false)
	self.Actives[activeCastID] = ActiveBlockcast.new({
		Output = self.Output,
		ActiveCastCleaner = self.ActiveCastCleaner,
		ObjectCache = self.ObjectCache
	}, activeCastID, Origin, Size, Direction, Velocity, Behavior)
end

function BaseCast:Destroy()
	for k, v in self.Actives do
		v:Terminate()
	end
	self.Actives = {}
	setmetatable(self, nil)
end


return BaseCast
