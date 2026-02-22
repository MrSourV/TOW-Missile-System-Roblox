-- Physics Visualizer — Script
-- This program isn't made by me, and only used to show the grid and missile trajectory.


local RunService = game:GetService("RunService")

local MISSILE_NAME       = "Missile"
local TRAIL_INTERVAL     = 0.06
local MAX_TRAIL          = 200
local GRAV_STEPS         = 30
local SPIRAL_STEPS       = 40
local VECTOR_UPDATE      = 0     -- every frame


local COL = {
	trail        = Color3.fromRGB(0, 255, 80),
	trailFast    = Color3.fromRGB(0, 255, 80),
	trailSlow    = Color3.fromRGB(0, 255, 80),
	velocity     = Color3.fromRGB(0, 255, 80),
	gravity      = Color3.fromRGB(0, 255, 80),
	drag         = Color3.fromRGB(0, 255, 80),
	thrust       = Color3.fromRGB(0, 255, 80),
	spiral       = Color3.fromRGB(0, 255, 80),
	gravArc      = Color3.fromRGB(0, 255, 80),
	grid         = Color3.fromRGB(0, 255, 80),
	gridAccent   = Color3.fromRGB(0, 255, 80),
	phase        = Color3.fromRGB(0, 255, 80),
	impactPred   = Color3.fromRGB(0, 255, 80),
	node         = Color3.fromRGB(0, 255, 80),
}
local function neonBall(size, color, trans)
	local p = Instance.new("Part")
	p.Shape        = Enum.PartType.Ball
	p.Size         = Vector3.new(size, size, size)
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = false
	p.Material     = Enum.Material.Neon
	p.Color        = color
	p.Transparency = trans or 0
	p.Parent       = workspace
	return p
end

local function neonBox(size, color, trans)
	local p = Instance.new("Part")
	p.Size         = size
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = false
	p.Material     = Enum.Material.Neon
	p.Color        = color
	p.Transparency = trans or 0
	p.Parent       = workspace
	return p
end

local function makeBeamPair(color, width, transparency)
	local a = Instance.new("Part")
	a.Size = Vector3.new(0.05,0.05,0.05)
	a.Anchored = true; a.CanCollide = false
	a.Transparency = 1; a.CastShadow = false
	a.Parent = workspace

	local b = Instance.new("Part")
	b.Size = Vector3.new(0.05,0.05,0.05)
	b.Anchored = true; b.CanCollide = false
	b.Transparency = 1; b.CastShadow = false
	b.Parent = workspace

	local att0 = Instance.new("Attachment", a)
	local att1 = Instance.new("Attachment", b)

	local beam = Instance.new("Beam")
	beam.Attachment0    = att0
	beam.Attachment1    = att1
	beam.Color          = ColorSequence.new(color)
	beam.Width0         = width or 0.07
	beam.Width1         = width or 0.07
	beam.FaceCamera     = true
	beam.LightInfluence = 0
	beam.Transparency   = NumberSequence.new(transparency or 0)
	beam.Segments       = 1
	beam.CurveSize0     = 0
	beam.CurveSize1     = 0
	beam.Parent         = a

	return a, b, beam
end

local function setBeam(pa, pb, from, to)
	pa.Position = from
	pb.Position = to
end

local function worldLabel(text, color, size)
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.1,0.1,0.1)
	part.Anchored = true; part.CanCollide = false
	part.Transparency = 1; part.CastShadow = false
	part.Parent = workspace

	local bb = Instance.new("BillboardGui", part)
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, size or 60, 0, 18)
	bb.LightInfluence = 0

	local lbl = Instance.new("TextLabel", bb)
	lbl.Size = UDim2.fromScale(1,1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color
	lbl.Text = text
	lbl.Font = Enum.Font.Code
	lbl.TextScaled = true
	lbl.BorderSizePixel = 0

	return part, lbl
end

local missile
local elapsed      = 0
local lastDotTime  = 0
local trailDots    = {}
local trailVels    = {}
local prevPos      = nil
local prevVel      = Vector3.zero
local gridBuilt    = false
local gridParts    = {}
local startPos


local velA,  velB,  velBeam  = makeBeamPair(COL.velocity,  0.12)
local gravA, gravB, gravBeam = makeBeamPair(COL.gravity,   0.09)
local dragA, dragB, dragBeam = makeBeamPair(COL.drag,      0.09)
local thrA,  thrB,  thrBeam  = makeBeamPair(COL.thrust,    0.12)

-- Arrow tip markers
local velTip  = neonBall(0.22, COL.velocity)
local gravTip = neonBall(0.18, COL.gravity)
local dragTip = neonBall(0.18, COL.drag)
local thrTip  = neonBall(0.22, COL.thrust)


local spiralDots = {}
for i = 1, SPIRAL_STEPS do
	local t = i / SPIRAL_STEPS
	local p = neonBall(0.10, COL.spiral, 0.2 + t * 0.7)
	table.insert(spiralDots, p)
end


local gravArcDots = {}
local gravArcBeams = {}
for i = 1, GRAV_STEPS do
	local t = i / GRAV_STEPS
	local p = neonBall(0.08, COL.gravArc, 0.3 + t * 0.6)
	table.insert(gravArcDots, p)
end
-- connect them with beams
for i = 1, GRAV_STEPS - 1 do
	local ga, gb, gbeam = makeBeamPair(COL.gravArc, 0.04, 0.5)
	table.insert(gravArcBeams, {ga=ga, gb=gb})
end

-- a thin neon ring (torus-ish built from arced beam) around missile
-- showing current motor phase color
local ringParts = {}
local RING_COUNT = 16
for i = 1, RING_COUNT do
	local p = neonBall(0.10, COL.phase, 0.1)
	table.insert(ringParts, p)
end
local impactDot = neonBall(0.5, COL.impactPred, 0.1)
local impCrossA1, impCrossA2, _ = makeBeamPair(COL.impactPred, 0.06)
local impCrossB1, impCrossB2, _ = makeBeamPair(COL.impactPred, 0.06)

-- Built once when missile spawns, shows the parabolic gravity well
-- as a green height-grid on the ground plane beneath the trajectory
local function buildGrid(origin)
	if gridBuilt then return end
	gridBuilt = true

	local GRID_SIZE  = 40
	local GRID_STEP  = 5
	local GRID_Y     = origin.Y - 2

	for x = -GRID_SIZE, GRID_SIZE, GRID_STEP do
		local pa, pb, beam = makeBeamPair(COL.gridAccent, 0.03, 0.6)
		pa.Position = Vector3.new(origin.X + x, GRID_Y, origin.Z - GRID_SIZE)
		pb.Position = Vector3.new(origin.X + x, GRID_Y, origin.Z + GRID_SIZE)
		table.insert(gridParts, {pa=pa, pb=pb, beam=beam})
	end
	for z = -GRID_SIZE, GRID_SIZE, GRID_STEP do
		local pa, pb, beam = makeBeamPair(COL.gridAccent, 0.03, 0.6)
		pa.Position = Vector3.new(origin.X - GRID_SIZE, GRID_Y, origin.Z + z)
		pb.Position = Vector3.new(origin.X + GRID_SIZE, GRID_Y, origin.Z + z)
		table.insert(gridParts, {pa=pa, pb=pb, beam=beam})
	end

	-- Three labeled axes at the launch origin showing the coordinate space
	local AXIS_LEN = 8

	-- X axis
	local xA, xB, xBeam = makeBeamPair(Color3.fromRGB(0, 255, 80), 0.07, 0)
	xA.Position = origin
	xB.Position = origin + Vector3.new(AXIS_LEN, 0, 0)
	table.insert(gridParts, {pa=xA, pb=xB, beam=xBeam})
	local xTip = neonBall(0.22, Color3.fromRGB(0, 255, 80), 0)
	xTip.Position = origin + Vector3.new(AXIS_LEN, 0, 0)
	table.insert(gridParts, {pa=xTip, pb=xTip, beam=xBeam})
	local xLbl, xLblTxt = worldLabel("+X", Color3.fromRGB(0, 255, 80), 40)
	xLbl.Position = origin + Vector3.new(AXIS_LEN + 0.8, 0, 0)
	table.insert(gridParts, {pa=xLbl, pb=xLbl, beam=xBeam})

	-- Y axis (up)
	local yUpA, yUpB, yUpBeam = makeBeamPair(Color3.fromRGB(0, 255, 80), 0.07, 0)
	yUpA.Position = origin
	yUpB.Position = origin + Vector3.new(0, AXIS_LEN, 0)
	table.insert(gridParts, {pa=yUpA, pb=yUpB, beam=yUpBeam})
	local yTip = neonBall(0.22, Color3.fromRGB(0, 255, 80), 0)
	yTip.Position = origin + Vector3.new(0, AXIS_LEN, 0)
	table.insert(gridParts, {pa=yTip, pb=yTip, beam=yUpBeam})
	local yLbl, yLblTxt = worldLabel("+Y", Color3.fromRGB(0, 255, 80), 40)
	yLbl.Position = origin + Vector3.new(0, AXIS_LEN + 0.8, 0)
	table.insert(gridParts, {pa=yLbl, pb=yLbl, beam=yUpBeam})

	-- Z axis
	local zA, zB, zBeam = makeBeamPair(Color3.fromRGB(0, 255, 80), 0.07, 0)
	zA.Position = origin
	zB.Position = origin + Vector3.new(0, 0, AXIS_LEN)
	table.insert(gridParts, {pa=zA, pb=zB, beam=zBeam})
	local zTip = neonBall(0.22, Color3.fromRGB(0, 255, 80), 0)
	zTip.Position = origin + Vector3.new(0, 0, AXIS_LEN)
	table.insert(gridParts, {pa=zTip, pb=zTip, beam=zBeam})
	local zLbl, zLblTxt = worldLabel("+Z", Color3.fromRGB(0, 255, 80), 40)
	zLbl.Position = origin + Vector3.new(0, 0, AXIS_LEN + 0.8)
	table.insert(gridParts, {pa=zLbl, pb=zLbl, beam=zBeam})

	-- Origin dot
	local originDot = neonBall(0.35, Color3.fromRGB(0, 255, 80), 0)
	originDot.Position = origin
	table.insert(gridParts, {pa=originDot, pb=originDot, beam=xBeam})
end

local PARABOLA_DOTS  = 50
local parabolaDots   = {}
local parabolaBuilt  = false

local function buildParabola(origin, initVel)
	if parabolaBuilt then return end
	parabolaBuilt = true

	local simP   = origin
	local simV   = initVel
	local step   = 0.12

	for i = 1, PARABOLA_DOTS do
		local t = i / PARABOLA_DOTS
		simV = simV + Vector3.new(0, -9.81, 0) * step
		simP = simP + simV * step

		local p = neonBall(0.09, Color3.fromRGB(0, 255, 80), 0.15 + t * 0.7)
		p.Position = simP
		table.insert(parabolaDots, p)
	end

	-- connect with thin green beams
	local prevPos2 = origin
	for _, dot in ipairs(parabolaDots) do
		local ga, gb, gbeam = makeBeamPair(Color3.fromRGB(0, 255, 80), 0.035, 0.55)
		ga.Position = prevPos2
		gb.Position = dot.Position
		prevPos2 = dot.Position
		table.insert(gridParts, {pa=ga, pb=gb, beam=gbeam})
	end
end

-- Larger glowing nodes dropped every 0.5s with a thin crosshair
local lastNodeTime = 0
local nodeParts    = {}

local function dropNode(pos, speed, phase)
	local col = phase == "BOOST"   and COL.thrust
		or phase == "SUSTAIN" and COL.velocity
		or phase == "COAST"   and COL.drag
		or COL.phase

	local core = neonBall(0.28, col, 0)
	core.Position = pos
	table.insert(nodeParts, core)

	-- crosshair (3 short lines through the node)
	local dirs = {
		Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1)
	}
	for _, d in ipairs(dirs) do
		local ca, cb, cbeam = makeBeamPair(col, 0.04, 0.4)
		ca.Position = pos - d * 0.6
		cb.Position = pos + d * 0.6
		table.insert(nodeParts, ca)
		table.insert(nodeParts, cb)
	end

	-- speed label next to node (small, offset to side)
	local lpart, llbl = worldLabel(string.format("%.0f m/s", speed), col, 55)
	lpart.Position = pos + Vector3.new(0.5, 0.4, 0)
	table.insert(nodeParts, lpart)

	task.delay(12, function()
		if core and core.Parent then core:Destroy() end
		if lpart and lpart.Parent then lpart:Destroy() end
	end)
end

local function fullCleanup()
	for _, p in ipairs(spiralDots)   do if p.Parent then p:Destroy() end end
	for _, p in ipairs(gravArcDots)  do if p.Parent then p:Destroy() end end
	for _, t in ipairs(gravArcBeams) do
		if t.ga.Parent then t.ga:Destroy() end
		if t.gb.Parent then t.gb:Destroy() end
	end
	for _, p in ipairs(ringParts)    do if p.Parent then p:Destroy() end end
	for _, p in ipairs(parabolaDots) do if p.Parent then p:Destroy() end end
	for _, t in ipairs(gridParts) do
		if t.pa and t.pa.Parent then t.pa:Destroy() end
		if t.pb and t.pb.Parent then t.pb:Destroy() end
	end
	velA:Destroy(); velB:Destroy()
	gravA:Destroy(); gravB:Destroy()
	dragA:Destroy(); dragB:Destroy()
	thrA:Destroy(); thrB:Destroy()
	velTip:Destroy(); gravTip:Destroy(); dragTip:Destroy(); thrTip:Destroy()
	impactDot:Destroy()
	impCrossA1:Destroy(); impCrossA2:Destroy()
	impCrossB1:Destroy(); impCrossB2:Destroy()
end
local function init()
	missile = workspace:WaitForChild(MISSILE_NAME, 15)
	if not missile then warn("[Viz] No missile found"); return end

	startPos = missile.Position
	prevPos  = startPos

	local EJECT_END  = 0.55
	local BOOST_END  = 0.95
	local SUS_END    = 4.95
	local MASS       = 18.9
	local AIR_DEN    = 1.225
	local DRAG_CD    = 0.38
	local CROSS_A    = 0.0095
	local BOOST_F    = 1800
	local SUSTAIN_F  = 700
	local SPIRAL_R   = 0.6
	local SPIRAL_SPD = 10
	local SPIRAL_SET = 3.5
	local GRAV       = Vector3.new(0, -9.81, 0)

	RunService.Heartbeat:Connect(function(dt)
		if not missile or not missile.Parent then
			fullCleanup(); return
		end

		elapsed = elapsed + dt
		local pos   = missile.Position
		local cf    = missile.CFrame
		local fwd   = cf.LookVector
		local right = cf.RightVector
		local upV   = cf.UpVector

		local vel    = (pos - prevPos) / math.max(dt, 0.001)
		local spd    = vel.Magnitude
		prevPos      = pos

		-- Motor phase
		local motorT    = elapsed - EJECT_END
		local thrustMag = 0
		local phase     = "EJECT"
		if motorT >= 0 and motorT < (BOOST_END - EJECT_END) then
			thrustMag = BOOST_F;   phase = "BOOST"
		elseif motorT >= (BOOST_END - EJECT_END) and motorT < SUS_END then
			thrustMag = SUSTAIN_F; phase = "SUSTAIN"
		elseif elapsed >= EJECT_END then
			phase = "COAST"
		end

		local dragMag = 0.5 * AIR_DEN * spd * spd * DRAG_CD * CROSS_A

		-- Build grid and parabola once
		buildGrid(startPos)
		if elapsed > EJECT_END + 0.05 and not parabolaBuilt then
			buildParabola(pos, vel)
		end

		if spd > 0.3 then
			local vlen = math.clamp(spd * 0.06, 0.3, 3.5)
			setBeam(velA, velB, pos, pos + vel.Unit * vlen)
			velTip.Position = pos + vel.Unit * vlen
		end

		setBeam(gravA, gravB, pos, pos + Vector3.new(0, -1.4, 0))
		gravTip.Position = pos + Vector3.new(0, -1.4, 0)

		if spd > 0.3 then
			local dlen = math.clamp(dragMag / 10, 0.1, 1.5)
			setBeam(dragA, dragB, pos, pos - vel.Unit * dlen)
			dragTip.Position = pos - vel.Unit * dlen
		end

		if thrustMag > 0 then
			local tlen = math.clamp(thrustMag / 700, 0.3, 3.0)
			setBeam(thrA, thrB, pos, pos + fwd * tlen)
			thrTip.Position  = pos + fwd * tlen
			thrBeam.Transparency = NumberSequence.new(0)
		else
			thrBeam.Transparency = NumberSequence.new(1)
			thrTip.Transparency  = 1
		end

		local ringCol = phase == "BOOST"   and COL.thrust
			or phase == "SUSTAIN" and COL.velocity
			or phase == "COAST"   and COL.drag
			or COL.phase
		local RING_R = 0.38
		for i, rp in ipairs(ringParts) do
			local a = (i / RING_COUNT) * math.pi * 2
			rp.Color    = ringCol
			rp.Position = pos + right * math.cos(a) * RING_R + upV * math.sin(a) * RING_R
		end

		local spiralFade = math.max(0, 1 - elapsed / SPIRAL_SET)
		if spiralFade > 0.01 then
			for i, dot in ipairs(spiralDots) do
				local ft    = elapsed + (i / SPIRAL_STEPS) * 2.0
				local fade2 = math.max(0, 1 - ft / SPIRAL_SET)
				local r     = SPIRAL_R * fade2
				local su    = math.sin(SPIRAL_SPD * ft) * r
				local ss    = math.cos(SPIRAL_SPD * ft) * r
				dot.Transparency = 0.2 + (i / SPIRAL_STEPS) * 0.75
				dot.Color        = COL.spiral
				dot.Position     = pos + fwd * (i * 0.28) + right * ss + upV * su
			end
		else
			for _, dot in ipairs(spiralDots) do dot.Transparency = 1 end
		end

		-- Simulate 3 seconds of gravity-only flight from here
		local simP = pos
		local simV = spd > 0.3 and vel or (fwd * spd)
		local step = 1.8 / GRAV_STEPS
		local prevArcPos = pos
		for i, dot in ipairs(gravArcDots) do
			simV = simV + GRAV * step
			simP = simP + simV * step
			dot.Position    = simP
			dot.Transparency = 0.25 + (i / GRAV_STEPS) * 0.6

			if i <= #gravArcBeams then
				local t = gravArcBeams[i]
				t.ga.Position = prevArcPos
				t.gb.Position = simP
			end
			prevArcPos = simP
		end

		-- Where does the arc eventually hit Y = ground level?
		local ipPos  = pos
		local ipVel  = spd > 0.3 and vel or (fwd * spd)
		local ground = startPos.Y - 1
		local ipStep = 0.08
		local maxIter = 300
		for _ = 1, maxIter do
			ipVel = ipVel + GRAV * ipStep
			ipPos = ipPos + ipVel * ipStep
			if ipPos.Y <= ground then break end
		end
		impactDot.Position = Vector3.new(ipPos.X, ground + 0.08, ipPos.Z)
		impactDot.Transparency = 0.1

		local crossSize = 1.1
		setBeam(impCrossA1, impCrossA2,
			impactDot.Position + Vector3.new(-crossSize, 0, 0),
			impactDot.Position + Vector3.new( crossSize, 0, 0))
		setBeam(impCrossB1, impCrossB2,
			impactDot.Position + Vector3.new(0, 0, -crossSize),
			impactDot.Position + Vector3.new(0, 0,  crossSize))

		if elapsed - lastDotTime >= TRAIL_INTERVAL then
			lastDotTime = elapsed

			-- color maps speed: slow=blue, fast=red
			local speedT = math.clamp(spd / 60, 0, 1)
			local tCol   = COL.trailSlow:Lerp(COL.trailFast, speedT)

			local dot = neonBall(0.10, tCol, 0.25)
			dot.Position = pos
			table.insert(trailDots, dot)
			table.insert(trailVels, spd)

			if #trailDots > MAX_TRAIL then
				local old = table.remove(trailDots, 1)
				table.remove(trailVels, 1)
				if old and old.Parent then old:Destroy() end
			end

			-- connect consecutive trail dots with thin beam
			if #trailDots >= 2 then
				local prev = trailDots[#trailDots - 1]
				local ga, gb, gbeam = makeBeamPair(tCol, 0.035, 0.55)
				ga.Position = prev.Position
				gb.Position = pos
			end
		end

		if elapsed - lastNodeTime >= 0.5 then
			lastNodeTime = elapsed
			dropNode(pos, spd, phase)
		end
	end)
end

init()
