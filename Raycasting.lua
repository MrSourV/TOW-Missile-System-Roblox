local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	BOOST_THRUST     = 1800,
	SUSTAIN_THRUST   = 700,
	EJECT_DURATION   = 0.55,
	BOOST_DURATION   = 0.4,
	SUSTAIN_DURATION = 4.0,
	MISSILE_MASS     = 18.9,
	LAUNCH_SPEED     = 18,
	AIR_DENSITY      = 1.225,
	DRAG_COEFF       = 0.38,
	CROSS_SECTION    = 0.0095,
	WOBBLE_AMPLITUDE = 5,
	WOBBLE_DAMPING   = 2.8,
	WOBBLE_FREQUENCY = 7,
	GUIDANCE_DELAY   = 1.2,
	MAX_TURN_RATE    = math.rad(18),
	GUIDANCE_GAIN    = 5.5,
	TARGET_NAME      = "Target",
	GRAVITY          = Vector3.new(0, -9.81, 0),
	DETONATE_RADIUS  = 3,
	MAX_RANGE        = 800,
	SPIRAL_RADIUS    = 0.6,
	SPIRAL_SPEED     = 10,
	SPIRAL_SETTLE    = 3.5,
	SPIRAL_DELAY     = 0.4,  
}

local missile   = script.Parent
local base      = workspace:FindFirstChild("base")
local target    = workspace:FindFirstChild(CONFIG.TARGET_NAME)

for i,v in pairs(script.Parent:GetDescendants()) do
	if v:IsA("ParticleEmitter") and v.Parent ~= script.Parent.Folder then
		v.Enabled = true
	end
end

local startPos  = missile.Position
local velocity  = missile.CFrame.LookVector * CONFIG.LAUNCH_SPEED
local elapsed   = 0
local isDead    = false

missile.Anchored   = true
missile.CanCollide = false

local particleAtt  = missile:FindFirstChild("particleattachment")
local smokeEmitter = particleAtt and particleAtt:FindFirstChild("Smoke")
local flameEmitter = particleAtt and particleAtt:FindFirstChild("Flame")

local p1Sound = missile:FindFirstChild("p1")
local p2Sound = missile:FindFirstChild("p2")

local function setParticles(smoke_rate, flame_rate, smoke_speed, flame_speed, flame_size)
	if smokeEmitter then
		smokeEmitter.Rate  = smoke_rate
		smokeEmitter.Speed = NumberRange.new(smoke_speed * 0.8, smoke_speed * 1.2)
	end
	if flameEmitter then
		flameEmitter.Rate  = flame_rate
		flameEmitter.Speed = NumberRange.new(flame_speed * 0.8, flame_speed * 1.2)
		if flame_size then
			flameEmitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   flame_size),
				NumberSequenceKeypoint.new(0.5, flame_size * 0.6),
				NumberSequenceKeypoint.new(1,   0),
			})
		end
	end
end

local function stopParticles()
	if smokeEmitter then smokeEmitter.Rate = 0 end
	if flameEmitter then flameEmitter.Rate = 0 end
end

if p1Sound then
	p1Sound.RollOffMaxDistance = 500
	p1Sound.Volume = 2.5
	p1Sound:Play()
end

if p2Sound then
	p2Sound.RollOffMaxDistance = 600
	p2Sound.Volume        = 0
	p2Sound.Looped        = true
	p2Sound.PlaybackSpeed = 1.1
	p2Sound:Play()
end

setParticles(0, 0, 0, 0, 0)

local motorPhase = "ejection"

local glowPart = Instance.new("Part")
glowPart.Size         = Vector3.new(0.1, 0.1, 0.1)
glowPart.Anchored     = true
glowPart.CanCollide   = false
glowPart.Transparency = 1
glowPart.CastShadow   = false
glowPart.Parent       = workspace

local exhaustLight = Instance.new("PointLight", glowPart)
exhaustLight.Color      = Color3.fromRGB(255, 140, 40)
exhaustLight.Brightness = 0
exhaustLight.Range      = 0
exhaustLight.Shadows    = true

local nosePart = Instance.new("Part")
nosePart.Size         = Vector3.new(0.1, 0.1, 0.1)
nosePart.Anchored     = true
nosePart.CanCollide   = false
nosePart.Transparency = 1
nosePart.CastShadow   = false
nosePart.Parent       = workspace

local noseLight = Instance.new("PointLight", nosePart)
noseLight.Color      = Color3.fromRGB(180, 210, 255)
noseLight.Brightness = 0
noseLight.Range      = 0

local STREAK_INTERVAL = 0.018
local lastStreakTime   = 0

local function spawnBoostStreak(pos)
	local s = Instance.new("Part")
	s.Shape        = Enum.PartType.Ball
	s.Size         = Vector3.new(0.22, 0.22, 0.22)
	s.Position     = pos
	s.Anchored     = true
	s.CanCollide   = false
	s.CastShadow   = false
	s.Material     = Enum.Material.Neon
	s.Color        = Color3.fromRGB(255, 120, 20)
	s.Transparency = 0.1
	s.Parent       = workspace

	TweenService:Create(s,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }
	):Play()

	task.delay(0.22, function()
		if s and s.Parent then s:Destroy() end
	end)
end

local WIRE_SEGMENTS = 22
local WIRE_WIDTH    = 0.09
local WIRE_COLOR    = Color3.fromRGB(8, 8, 8)
local SAG_SCALE     = 0.07
local SAG_RAMP_TIME = 1.8
local WIRE_OFFSETS  = {
	Vector3.new(0,  0.12,  0.20),
	Vector3.new(0,  0.12, -0.20),
}

local function buildWire()
	local data = { nodes = {}, beams = {} }
	for i = 1, WIRE_SEGMENTS + 1 do
		local node = Instance.new("Part")
		node.Name         = "WireNode"
		node.Size         = Vector3.new(0.1, 0.1, 0.1)
		node.Anchored     = true
		node.CanCollide   = false
		node.Transparency = 1
		node.CastShadow   = false
		node.Parent       = workspace
		local attOut = Instance.new("Attachment", node)
		local attIn  = Instance.new("Attachment", node)
		table.insert(data.nodes, { part = node, attOut = attOut, attIn = attIn })
	end
	for i = 1, WIRE_SEGMENTS do
		local beam = Instance.new("Beam")
		beam.Attachment0    = data.nodes[i].attOut
		beam.Attachment1    = data.nodes[i + 1].attIn
		beam.Color          = ColorSequence.new(WIRE_COLOR)
		beam.Width0         = WIRE_WIDTH
		beam.Width1         = WIRE_WIDTH
		beam.FaceCamera     = true
		beam.Segments       = 1
		beam.CurveSize0     = 0
		beam.CurveSize1     = 0
		beam.LightInfluence = 0
		beam.Transparency   = NumberSequence.new(0)
		beam.Parent         = data.nodes[i].part
		table.insert(data.beams, beam)
	end
	return data
end

local function updateWire(data, p0, p1, t)
	local n       = WIRE_SEGMENTS
	local length  = (p1 - p0).Magnitude
	local sagRamp = math.min(t / SAG_RAMP_TIME, 1)
	for i = 1, n + 1 do
		local f       = (i - 1) / n
		local pos     = p0:Lerp(p1, f)
		local sag     = SAG_SCALE * length * f * (1 - f) * sagRamp
		local flutter = math.sin(t * 6 + f * math.pi) * 0.025 * sagRamp
		data.nodes[i].part.Position = pos + Vector3.new(flutter, -sag, 0)
	end
end

local function destroyWires(w1, w2)
	for _, wire in ipairs({ w1, w2 }) do
		if wire then
			for _, n in ipairs(wire.nodes) do
				if n.part and n.part.Parent then n.part:Destroy() end
			end
		end
	end
end

local wire1, wire2
if base then
	wire1 = buildWire()
	wire2 = buildWire()
	print("[TOW] Wires active")
else
	warn("[TOW] No Part named 'base' found — wires disabled")
end

local function getDrag(vel)
	local spd = vel.Magnitude
	if spd < 0.01 then return Vector3.zero end
	return -vel.Unit * (0.5 * CONFIG.AIR_DENSITY * spd * spd * CONFIG.DRAG_COEFF * CONFIG.CROSS_SECTION)
end

local function getThrust(t)
	local motorT = t - CONFIG.EJECT_DURATION
	if motorT < 0 then return 0
	elseif motorT <= CONFIG.BOOST_DURATION then return CONFIG.BOOST_THRUST
	elseif motorT <= CONFIG.BOOST_DURATION + CONFIG.SUSTAIN_DURATION then return CONFIG.SUSTAIN_THRUST
	end
	return 0
end

local function getWobble(t)
	if t > CONFIG.GUIDANCE_DELAY + 2.2 then return 0 end
	return math.rad(CONFIG.WOBBLE_AMPLITUDE) * math.exp(-CONFIG.WOBBLE_DAMPING * t) * math.cos(CONFIG.WOBBLE_FREQUENCY * t)
end

local function getGuidance(mPos, tPos, fwd)
	local toTarget = tPos - mPos
	if toTarget.Magnitude < 0.5 then return Vector3.zero end
	local err = toTarget.Unit - fwd
	local correction = err * CONFIG.GUIDANCE_GAIN
	if correction.Magnitude > CONFIG.MAX_TURN_RATE then
		correction = correction.Unit * CONFIG.MAX_TURN_RATE
	end
	return correction
end

local lastHitPart = nil

local function triggerExplosionSequence(hitPart, hitPos)
	-- so anchored parts actually get thrown
	local BLAST_RADIUS = 18
	for _, obj in ipairs(workspace:GetPartBoundsInRadius(hitPos, BLAST_RADIUS)) do
		if obj ~= missile and obj.Name ~= "WireNode"
			and obj.Name ~= "base" and  obj.Name ~= "baser" and not obj:IsDescendantOf(missile) then
			obj.Anchored  = false
			obj.CanCollide = true
		end
	end

	-- small delay so unanchoring propagates before blast force hits
	task.delay(0.02, function()
		local explosion = Instance.new("Explosion")
		explosion.Position                  = hitPos
		explosion.BlastRadius               = BLAST_RADIUS
		explosion.BlastPressure             = 1200000
		explosion.DestroyJointRadiusPercent = 1.0
		explosion.ExplosionType             = Enum.ExplosionType.Craters
		explosion.Visible                   = false
		explosion.Parent                    = workspace
	end)

	local folder = missile:FindFirstChild("Folder")
	if not folder then return end

	local anchor = Instance.new("Part")
	anchor.Size         = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.Transparency = 1
	anchor.CastShadow   = false
	anchor.Position     = hitPos
	anchor.Parent       = hitPart or workspace

	local attach = Instance.new("Attachment")
	attach.Position = Vector3.new(0, 0, 0)
	attach.Parent   = anchor

	local emitters = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			local e = child:Clone()
			e.Enabled = false
			local ks = e.Size.Keypoints
			local newKs = {}
			for _, kp in ipairs(ks) do
				table.insert(newKs, NumberSequenceKeypoint.new(kp.Time, kp.Value * 4, kp.Envelope * 4))
			end
			e.Size = NumberSequence.new(newKs)
			e.Parent = attach
			emitters[child.Name] = e
		end
	end

	local explodeLight = Instance.new("PointLight", anchor)
	explodeLight.Color      = Color3.fromRGB(255, 160, 40)
	explodeLight.Brightness = 12
	explodeLight.Range      = 60
	explodeLight.Shadows    = true
	TweenService:Create(explodeLight,
		TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Brightness = 0, Range = 10 }
	):Play()

	local function emit(name, count)
		local e = emitters[name]
		if e then e:Emit(count) end
	end

	emit("Explosion",  60)
	task.delay(0.04, function() emit("Shockwave",  8)  end)
	task.delay(0.08, function() emit("Sparks",    150)  end)
	task.delay(0.10, function() emit("Smoke1",     35)  end)
	task.delay(0.18, function() emit("Debris",     30)  end)
	task.delay(0.22, function() emit("Explosion",  25)  end)
	task.delay(0.28, function() emit("Smoke2",     40)  end)
	task.delay(0.35, function() emit("Sparks",     80)  end)
	task.delay(0.40, function() emit("Debris2",    25)  end)
	task.delay(0.55, function() emit("Smoke3",     50)  end)
	task.delay(0.75, function() emit("Smoke1",     30)  end)
	task.delay(0.90, function() emit("Smoke4",     60)  end)
	task.delay(1.20, function() emit("Smoke3",     40)  end)
	task.delay(1.60, function() emit("Smoke4",     50)  end)
	task.delay(2.20, function() emit("Smoke4",     40)  end)

	local sound = script.Parent:FindFirstChild("Giant Explosion")
	if sound then
		local s = sound:Clone()
		s.Parent = anchor
		s:Play()
	end

	task.delay(10, function()
		if anchor and anchor.Parent then anchor:Destroy() end
	end)
end

local connection

local function detonate(hitPart)
	if isDead then return end
	isDead = true
	if connection then connection:Disconnect() end
	stopParticles()
	exhaustLight.Brightness = 0
	exhaustLight.Range      = 0
	noseLight.Brightness    = 0
	if glowPart and glowPart.Parent then glowPart:Destroy() end
	if nosePart and nosePart.Parent then nosePart:Destroy() end
	if p2Sound then
		TweenService:Create(p2Sound, TweenInfo.new(0.1), { Volume = 0 }):Play()
		task.delay(0.15, function() if p2Sound then p2Sound:Stop() end end)
	end
	destroyWires(wire1, wire2)
	local explodePos = missile.Position
	triggerExplosionSequence(hitPart, explodePos)
	missile:Destroy()
end

connection = RunService.Heartbeat:Connect(function(dt)
	if isDead then return end
	elapsed = elapsed + dt

	if (missile.Position - startPos).Magnitude > CONFIG.MAX_RANGE then
		detonate(nil); return
	end

	if target and target.Parent then
		if (missile.Position - target.Position).Magnitude <= CONFIG.DETONATE_RADIUS then
			detonate(target); return
		end
	end

	local fwd         = missile.CFrame.LookVector
	local thrust      = getThrust(elapsed)
	local thrustForce = fwd * thrust

	local gravForce, dragForce
	if elapsed < CONFIG.EJECT_DURATION then
		gravForce = Vector3.zero
		dragForce = Vector3.zero
	else
		gravForce = CONFIG.GRAVITY * CONFIG.MISSILE_MASS
		dragForce = getDrag(velocity)
	end

	local accel = (thrustForce + gravForce + dragForce) / CONFIG.MISSILE_MASS
	velocity = velocity + accel * dt

	local basePos2 = missile.Position + velocity * dt

	-- Both sin and cos offset by -cos(0)/sin(0) so there's no sudden kick on frame 1
	local spiralT    = math.max(0, elapsed - CONFIG.SPIRAL_DELAY)
	local spiralFade = 1 - math.min(spiralT / CONFIG.SPIRAL_SETTLE, 1)
	local spiralR    = CONFIG.SPIRAL_RADIUS * spiralFade
	local spiralUp   = math.sin(CONFIG.SPIRAL_SPEED * spiralT) * spiralR
	local spiralSide = math.sin(CONFIG.SPIRAL_SPEED * spiralT + math.pi / 2) * spiralR * (1 - math.exp(-CONFIG.SPIRAL_SPEED * spiralT * 0.3))

	local right  = missile.CFrame.RightVector
	local up2    = missile.CFrame.UpVector
	local newPos = basePos2 + right * spiralSide + up2 * spiralUp

	local wobble  = getWobble(elapsed)
	local lookDir = velocity.Magnitude > 0.1 and velocity.Unit or fwd

	missile.CFrame =
		CFrame.lookAt(newPos, newPos + lookDir) *
		CFrame.Angles(wobble, 0, 0)

	if elapsed > CONFIG.GUIDANCE_DELAY and target and target.Parent then
		local corr = getGuidance(missile.Position, target.Position, fwd)
		velocity   = velocity + corr * velocity.Magnitude * dt
	end

	local motorT    = elapsed - CONFIG.EJECT_DURATION
	local speed     = velocity.Magnitude
	local tailPos   = missile.Position - missile.CFrame.LookVector * (missile.Size.Z * 0.5)
	local nosePos   = missile.Position + missile.CFrame.LookVector * (missile.Size.Z * 0.5)

	glowPart.Position = tailPos
	nosePart.Position = nosePos

	local speedFrac = math.clamp(speed / 80, 0, 1)
	noseLight.Brightness = speedFrac * 0.6
	noseLight.Range      = speedFrac * 6

	local flicker = 1 + (math.random() - 0.5) * 0.3

	if elapsed < CONFIG.EJECT_DURATION then
		if motorPhase ~= "eject" then
			motorPhase = "eject"
			setParticles(0, 0, 0, 0, 0)
			exhaustLight.Brightness = 0
			exhaustLight.Range      = 0
			if p2Sound then p2Sound.Volume = 0 end
		end

	elseif motorT <= CONFIG.BOOST_DURATION then
		if motorPhase ~= "boost" then
			motorPhase = "boost"
			setParticles(80, 120, 12, 18, 0.55)
			if p2Sound then
				p2Sound.PlaybackSpeed = 1.3
				TweenService:Create(p2Sound, TweenInfo.new(0.08), { Volume = 2.8 }):Play()
			end
		end
		exhaustLight.Brightness = 4.5 * flicker
		exhaustLight.Range      = 18

		if elapsed - lastStreakTime >= STREAK_INTERVAL then
			lastStreakTime = elapsed
			spawnBoostStreak(tailPos)
		end

	elseif motorT <= CONFIG.BOOST_DURATION + CONFIG.SUSTAIN_DURATION then
		if motorPhase ~= "sustain" then
			motorPhase = "sustain"
			setParticles(35, 55, 7, 10, 0.35)
			if p2Sound then
				TweenService:Create(p2Sound, TweenInfo.new(0.3), { Volume = 2.0, PlaybackSpeed = 1.05 }):Play()
			end
		end
		exhaustLight.Brightness = 2.2 * flicker
		exhaustLight.Range      = 12

	else
		if motorPhase ~= "coast" then
			motorPhase = "coast"
			setParticles(8, 0, 3, 0, 0)
			if p2Sound then
				TweenService:Create(p2Sound, TweenInfo.new(0.6), { Volume = 0.6, PlaybackSpeed = 0.85 }):Play()
			end
		end
		TweenService:Create(exhaustLight, TweenInfo.new(0.5), { Brightness = 0, Range = 0 }):Play()
	end

	if base and wire1 and wire2 then
		local basePos = base.Position
		updateWire(wire1, basePos + WIRE_OFFSETS[1], tailPos + WIRE_OFFSETS[1], elapsed)
		updateWire(wire2, basePos + WIRE_OFFSETS[2], tailPos + WIRE_OFFSETS[2], elapsed)
	end
end)
