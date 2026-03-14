--!strict

local Server: typeof(require(script.Server))
local Client: typeof(require(script.Client))

if game:GetService("RunService"):IsServer() then
	Server = require(script.Server)
else
	Client = require(script.Client)
end

return {
	Server = Server,
	Client = Client,
}