FrameBufferTestMixin = {}

function FrameBufferTestMixin:OnLoad()
    self.ScreenWidth = 320
    self.ScreenHeight = 50
   
    self:SetToplevel(true)
    -- self:SetIsFrameBuffer(false)
    self:SetAlpha(1)
    self:SetSize(self.ScreenWidth * 2, self.ScreenHeight * 2)
   
    self.FrameBuffer = {}
    for i = 0, self.ScreenHeight-1 do
        for j = 0, self.ScreenWidth-1 do
            local pixel = self:CreateTexture()
            pixel:SetColorTexture(i/self.ScreenHeight, j/self.ScreenWidth, 0)
            pixel:SetSize(2, 2)
            pixel:SetDrawLayer("ARTWORK", 1)
            table.insert(self.FrameBuffer, pixel)
        end
    end

    local initialAnchor = AnchorUtil.CreateAnchor("TOPLEFT", self, "TOPLEFT", 0, 0)
    local layout = AnchorUtil.CreateGridLayout(GridLayoutMixin.Direction.TopLeftToBottomRight, self.ScreenWidth, 0, 0)
    AnchorUtil.GridLayout(self.FrameBuffer, initialAnchor, layout)
end

FrameBufferTestFrame = Mixin(CreateFrame("Frame", nil, UIParent), FrameBufferTestMixin)
FrameBufferTestFrame:OnLoad()
FrameBufferTestFrame:SetPoint("CENTER")