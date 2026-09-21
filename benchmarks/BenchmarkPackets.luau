--// Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

local ByteNet = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ByteNet"))

--// Packets

return ByteNet.defineNamespace("FastCast2Benchmarks", function()
	return {
		Input = ByteNet.definePacket({
			value = ByteNet.string,
		}),
	}
end)
