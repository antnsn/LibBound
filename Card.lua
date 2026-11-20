-- LibBound cards: the one look for reminders (a buff that is missing or running out, water to
-- conjure...). The spell icon on a dark panel with a double rule, dressed by the skin:
--   burst   = "Sunburst"  a light behind the icon that turns slowly and breathes (Lightbound)
--   ring    = "Ring"      a ring around a round icon;  round = true masks the icon round
--   studs   = "Stud"      ornaments in the corners
--   frost   = "Frost"     a frosted-glass layer over the panel (Chronobound)
--   shards  = "Shard"     crystal shards cut into the corners
--   crest   = "Crest"     a large faint class motif behind the right side, cut off by the edge
--                         (crestTint = { r, g, b, a }); also in the options window and travel panel
--   breathe = true        the edge itself breathes while the card glows
-- Texture names are files in the addon's Media folder. Quiet on purpose: no flicker, no swelling.
-- card:SetIcon(tex), SetTitle(text), SetStatus(text, urgent), SetFaded(on), Glow(on), SetExplain(text)
local lib = LibStub("LibBound-1.0")
if not lib or not lib.installing then return end -- this copy lost to a newer one (Core.lua)

local function SetGradient(tex, top, bottom)
	-- newer clients take colour objects, older ones plain numbers
	if CreateColor and pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top))) then return end
	pcall(tex.SetGradientAlpha, tex, "VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4], top[1], top[2], top[3], top[4])
end

function lib.InstallCards(ns)
	local MEDIA = ns.MEDIA
	local CARD = setmetatable({}, { __index = function(_, k) return ns.UI.CARD[k] end })

	function ns.MakeCard(name, opts)
		opts = opts or {}
		local W, H, ICON = opts.width or 230, 56, 34
		local c = CreateFrame("Frame", name, UIParent)
		c:SetSize(W, H)
		c:SetFrameStrata("LOW")
		c:SetClipsChildren(true) -- the light behind the icon is larger than the card
		c:Hide()

		-- panel, light from above, double rule
		local outer = c:CreateTexture(nil, "BACKGROUND", nil, 0)
		outer:SetAllPoints(); outer:SetColorTexture(unpack(CARD.gilt))
		local inner = c:CreateTexture(nil, "BACKGROUND", nil, 1)
		inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
		inner:SetColorTexture(unpack(CARD.panel))
		if CARD.frost then
			local glass = c:CreateTexture(nil, "BACKGROUND", nil, 2)
			glass:SetPoint("TOPLEFT", 1, -1); glass:SetPoint("BOTTOMRIGHT", -1, 1)
			glass:SetTexture(MEDIA .. CARD.frost, "REPEAT", "REPEAT")
			glass:SetHorizTile(true); glass:SetVertTile(true)
			glass:SetVertexColor(unpack(CARD.frostTint or { 0.75, 0.92, 1, 0.10 }))
		end
		if CARD.crest then
			local crest = c:CreateTexture(nil, "BACKGROUND", nil, 2)
			crest:SetTexture(MEDIA .. CARD.crest)
			crest:SetSize(H * 1.8, H * 1.8)
			crest:SetPoint("CENTER", c, "RIGHT", -H * 0.45, -H * 0.1)
			crest:SetVertexColor(unpack(CARD.crestTint or { 1, 1, 1, 0.16 }))
		end
		local light = c:CreateTexture(nil, "BACKGROUND", nil, 3)
		light:SetPoint("TOPLEFT", 1, -1); light:SetPoint("TOPRIGHT", -1, -1); light:SetHeight(H * 0.6)
		light:SetColorTexture(1, 1, 1, 1)
		SetGradient(light, CARD.light, { CARD.light[1], CARD.light[2], CARD.light[3], 0 })
		local function Rule(p1, p2, horizontal)
			local t = c:CreateTexture(nil, "BACKGROUND", nil, 4)
			t:SetColorTexture(unpack(CARD.giltFaint))
			t:SetPoint(p1[1], p1[2], p1[3]); t:SetPoint(p2[1], p2[2], p2[3])
			if horizontal then t:SetHeight(1) else t:SetWidth(1) end
		end
		Rule({ "TOPLEFT", 4, -4 }, { "TOPRIGHT", -4, -4 }, true)
		Rule({ "BOTTOMLEFT", 4, 4 }, { "BOTTOMRIGHT", -4, 4 }, true)
		Rule({ "TOPLEFT", 4, -4 }, { "BOTTOMLEFT", 4, 4 }, false)
		Rule({ "TOPRIGHT", -4, -4 }, { "BOTTOMRIGHT", -4, 4 }, false)

		local glowFrame = CreateFrame("Frame", nil, c)
		glowFrame:SetAllPoints()
		local medal = CreateFrame("Frame", nil, c)
		medal:SetSize(ICON + 6, ICON + 6); medal:SetPoint("LEFT", 9, 0)
		medal:SetFrameLevel(glowFrame:GetFrameLevel() + 2)

		-- the light behind the icon (a skin with `burst`): turns slowly and breathes while glowing
		local rays, turn, breathe
		if CARD.burst then
			rays = glowFrame:CreateTexture(nil, "ARTWORK")
			rays:SetTexture(MEDIA .. CARD.burst); rays:SetBlendMode("ADD")
			rays:SetSize(ICON * 2.3, ICON * 2.3); rays:SetPoint("CENTER", medal)
			rays:SetVertexColor(unpack(CARD.rays)); rays:SetAlpha(0.55)
			turn = rays:CreateAnimationGroup()
			turn:SetLooping("REPEAT")
			local spin = turn:CreateAnimation("Rotation")
			spin:SetDegrees(-360); spin:SetDuration(CARD.spin or 90) -- you feel it more than see it
			breathe = rays:CreateAnimationGroup()
			breathe:SetLooping("BOUNCE")
			local a = breathe:CreateAnimation("Alpha")
			a:SetFromAlpha(0.45); a:SetToAlpha(0.95); a:SetDuration(2.2); a:SetSmoothing("IN_OUT")
		end

		-- a breathing rim (a skin with `breathe`): a soft glow along the edge while the card glows
		local rim, rimPulse
		if CARD.breathe then
			rim = glowFrame:CreateTexture(nil, "ARTWORK")
			rim:SetPoint("TOPLEFT", 0, 0); rim:SetPoint("BOTTOMRIGHT", 0, 0)
			if CARD.rim then rim:SetTexture(MEDIA .. CARD.rim) else rim:SetColorTexture(1, 1, 1, 1) end
			rim:SetBlendMode("ADD")
			rim:SetVertexColor(unpack(CARD.rays))
			rim:SetAlpha(0)
			rimPulse = rim:CreateAnimationGroup()
			rimPulse:SetLooping("BOUNCE")
			local a = rimPulse:CreateAnimation("Alpha")
			a:SetFromAlpha(0.15); a:SetToAlpha(0.55); a:SetDuration(CARD.breatheTime or 2.5); a:SetSmoothing("IN_OUT")
		end

		local icon = medal:CreateTexture(nil, "ARTWORK")
		icon:SetSize(ICON, ICON); icon:SetPoint("CENTER")
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local masked = not CARD.round -- square skins skip the mask and frame the icon in 1px
		if masked then
			local edge = medal:CreateTexture(nil, "BACKGROUND")
			edge:SetPoint("TOPLEFT", icon, -1, 1); edge:SetPoint("BOTTOMRIGHT", icon, 1, -1)
			edge:SetColorTexture(unpack(CARD.iconEdge or { 0, 0, 0, 1 }))
		elseif medal.CreateMaskTexture and icon.AddMaskTexture then
			local ok, mask = pcall(medal.CreateMaskTexture, medal)
			if ok and mask then
				mask:SetTexture(MEDIA .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetAllPoints(icon)
				masked = pcall(icon.AddMaskTexture, icon, mask)
			end
		end
		if not masked and icon.SetMask then pcall(icon.SetMask, icon, MEDIA .. "RoundMask") end
		if CARD.ring then
			local ring = medal:CreateTexture(nil, "OVERLAY")
			ring:SetTexture(MEDIA .. CARD.ring); ring:SetAllPoints()
		end
		for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
			if CARD.studs then
				local stud = medal:CreateTexture(nil, "OVERLAY")
				stud:SetTexture(MEDIA .. CARD.studs); stud:SetSize(9, 9)
				stud:SetPoint(p, c, p, 0, 0)
			end
			if CARD.shards then
				-- the shard texture points into the top-left corner; mirror it for the others
				local shard = medal:CreateTexture(nil, "OVERLAY")
				shard:SetTexture(MEDIA .. CARD.shards); shard:SetSize(12, 12)
				shard:SetPoint(p, c, p, 0, 0)
				local l, r = p:find("RIGHT") and 1 or 0, p:find("RIGHT") and 0 or 1
				local t, b = p:find("BOTTOM") and 1 or 0, p:find("BOTTOM") and 0 or 1
				shard:SetTexCoord(l, r, t, b)
				shard:SetVertexColor(unpack(CARD.shardTint or CARD.gilt))
			end
		end

		local title = medal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		if not ns.UI.SetFont(title, "card", 16) then title:SetFontObject("GameFontNormalLarge") end
		title:SetPoint("BOTTOMLEFT", medal, "RIGHT", 11, 0); title:SetPoint("RIGHT", c, "RIGHT", -10, 0)
		title:SetJustifyH("LEFT"); title:SetTextColor(unpack(CARD.title)); title:SetWordWrap(false)
		title:SetShadowColor(0, 0, 0, 1); title:SetShadowOffset(1, -1)
		local status = medal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3); status:SetPoint("RIGHT", c, "RIGHT", -10, 0)
		status:SetJustifyH("LEFT"); status:SetTextColor(unpack(CARD.status)); status:SetWordWrap(false)

		local faded, glowing = false, false
		local function Light()
			if rays then
				rays:SetVertexColor(unpack(faded and CARD.raysFaded or CARD.rays))
				if glowing and not faded then
					if not turn:IsPlaying() then turn:Play() end
					if not breathe:IsPlaying() then breathe:Play() end
				else
					breathe:Stop()
					rays:SetAlpha(faded and 0.18 or 0.55)
					if faded then turn:Pause() elseif glowing and not turn:IsPlaying() then turn:Play() end
				end
			end
			if rim then
				if glowing and not faded then
					if not rimPulse:IsPlaying() then rimPulse:Play() end
				else
					rimPulse:Stop(); rim:SetAlpha(0)
				end
			end
			if not rays and not rim then
				outer:SetColorTexture(unpack(glowing and not faded and CARD.glowEdge or CARD.gilt))
			end
		end

		function c:SetIcon(tex) icon:SetTexture(tex) end
		function c:SetTitle(text) title:SetText(text or "") end
		function c:SetStatus(text, urgent)
			status:SetText(text or "")
			status:SetTextColor(unpack(urgent and CARD.urgent or CARD.status))
		end
		function c:SetFaded(on)
			faded = on and true or false
			icon:SetDesaturated(faded)
			Light()
		end
		function c:Glow(on)
			glowing = on and true or false
			if turn and not glowing then turn:Stop() end
			Light()
		end
		-- a plain-word explanation in the card's tooltip (when the player keeps explanations on);
		-- cards then take mouse-over but not clicks, so the world under them stays clickable
		function c:SetExplain(text)
			c.explain = text
			if c.SetMouseClickEnabled then
				c:SetMouseMotionEnabled(text ~= nil)
				if not ns.unlocked then c:SetMouseClickEnabled(false) end
			end
		end
		c:SetScript("OnEnter", function(self)
			if not self.explain or not ns.db.explain or ns.unlocked then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(title:GetText() or "")
			GameTooltip:AddLine(self.explain, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
		c.icon, c.titleText, c.statusText = icon, title, status
		c.IsGlowing = function() return glowing end
		c.IsFaded = function() return faded end
		return c
	end
end
