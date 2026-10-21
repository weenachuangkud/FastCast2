local storage = game:GetService("ReplicatedStorage")
game:GetService("RunService"):Run()
local deadline = os.clock() + 180
while storage:GetAttribute("HotPathResult") == nil and os.clock() < deadline do
	task.wait(0.2)
end
print(storage:GetAttribute("HotPathResult") or "HOTPATH_TIMEOUT")
