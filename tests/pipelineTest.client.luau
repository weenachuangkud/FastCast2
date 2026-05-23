--[[
    - Author: Mawin CK
]]

--[[
    Run this inside StarterPlayerScripts

    NOTE:
        I never wrote this script to be readable
        So don't expect this to be readable
        Because it's never meant to be readable
]]

print("Starting test..")

task.wait(5)

local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")

local Path = Rep
local FastCastM = Path:WaitForChild("FastCast2")
local FastCast = require(FastCastM)
local TypeDef = require(FastCastM:WaitForChild("TypeDefinitions"))

if not RS:IsClient() then
    print("Please this UnitTest as client sided")
    return
end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local projectileTemplate = Instance.new("Part")
projectileTemplate.Name = "Projectile"
projectileTemplate.Size = Vector3.new(1,1,1)
projectileTemplate.Parent = Rep
projectileTemplate.Anchored = true
projectileTemplate.Massless = true
projectileTemplate.Position = Vector3.new(0,0,0)
projectileTemplate.CanCollide = false
projectileTemplate.CanTouch = false
projectileTemplate.CanQuery = false

local projetileContainer = Instance.new("Folder")
projetileContainer.Name = "ProjectileContainer"
projetileContainer.Parent = workspace

local castParamsTemplate = RaycastParams.new()
castParamsTemplate.FilterDescendantsInstances = {character}
castParamsTemplate.FilterType = Enum.RaycastFilterType.Exclude
castParamsTemplate.IgnoreWater = true

local function CloneCastParams(params: RaycastParams): RaycastParams
	local clone: RaycastParams = RaycastParams.new()
	clone.CollisionGroup = params.CollisionGroup
	clone.FilterType = params.FilterType
	clone.FilterDescendantsInstances = {table.unpack(params.FilterDescendantsInstances)}
	clone.IgnoreWater = params.IgnoreWater
	clone.RespectCanCollide = params.RespectCanCollide
	return clone
end

local behaviorTemplate = FastCast.newBehavior()
behaviorTemplate.Acceleration = Vector3.new(1,1,1)
behaviorTemplate.AutoIgnoreContainer = true
behaviorTemplate.CosmeticBulletContainer = projetileContainer
behaviorTemplate.CosmeticBulletTemplate = projectileTemplate
behaviorTemplate.HighFidelitySegmentSize = 1
behaviorTemplate.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
behaviorTemplate.RaycastParams = castParamsTemplate
behaviorTemplate.MaxDistance = 1000
behaviorTemplate.UserData = {}

type CasterMode = "Parallel" | "Serial" | "Both"

local Tests: {
    {
        name: string,
        mode: string,
        waitTime: number,
        fn: () -> ()
    }
} = {}

local function runTests()
    local PASS_parallel = 0
    local PASS_both = 0
    local PASS_serial = 0
    local FAIL_parallel = 0
    local FAIL_both = 0
    local FAIL_serial = 0

   for _, v in Tests do
        local ok, err = pcall(v.fn)
        if ok then 
            print("[PASSED]: " .. v.name)
            if v.mode == "Parallel" then
                PASS_parallel += 1
            elseif v.mode == "Serial" then
                PASS_serial += 1
            elseif v.mode == "Both" then
                PASS_both += 1
            end
        else
            warn("[FAILED]:" .. v.name)
            if err then
                warn("ERROR: " .. tostring(err))
            end
             if v.mode == "Parallel" then
                FAIL_parallel -= 1
            elseif v.mode == "Serial" then
                FAIL_serial -= 1
            elseif v.mode == "Both" then
                FAIL_both -= 1
            end
        end

        if v.waitTime then
            task.wait(v.waitTime)
        else
            task.wait(0.5)
        end
    end

    local rep_num = 30

    print(string.rep("=", rep_num))
    print("PARALLEL")
    print(string.rep("=", rep_num))
    print("PASSED: " .. tostring(PASS_parallel))
    print("FAILED:" .. tostring(FAIL_parallel))

    print(string.rep("=", rep_num))
    print("SERIAL")
    print(string.rep("=", rep_num))
    print("PASSED: " .. tostring(PASS_serial))
    print("FAILED: " .. tostring(FAIL_serial))

    print(string.rep("=", rep_num))
    print("BOTH")
    print(string.rep("=", rep_num))
    print("PASSED: " .. tostring(PASS_both))
    print("FAILED: " .. tostring(FAIL_both))
end

local function addTest(name: string, mode: CasterMode, waitTime: number, fn: () -> ())
    table.insert(
        Tests,
        {
            name = name,
            mode = mode,
            waitTime = waitTime or 0.5,
            fn = fn
        }
    )
end

addTest("Serial caster basic", "Serial", 1, function()
    print("Init serial caster..")

    local caster = FastCast.new()
    caster:Init("BulkMoveTo")

    print("Init serial caster successfully..")

    print("[DEBUG] Serial caster data: ", caster)

    print("Setting MovementMode = Motor6D")
    caster:SetMovementMode("Motor6D")

    print("Setting MovementMode = BulkMoveTo")
    caster:SetMovementMode("BulkMoveTo")

    print("Set ObjectCache")
    caster:SetObjectCacheEnabled(true, projectileTemplate, 100, projetileContainer)

    print("[DEBUG] Serial caster data: ", caster)


    task.wait(0.5)

    print("Unset ObjectCache")
    caster:SetObjectCacheEnabled(false)

    print("[DEBUG] Serial caster data: ", caster)

    print("Destroying")
    caster:Destroy()

    print("[DEBUG] Serial caster data: ", caster)

    caster = nil
end)

runTests()