local vga_to_rgb = {}

RV32_KEYMAP = {
    W = 0,
    A = 1,
    S = 2,
    D = 3,
    R = 4,
    F = 5,
    LCTRL = 0x1000,
    LSHIFT = 0x1001,
    SPACE = 0x1002,
    LALT = 0x1003,
    ENTER = 0x1004,
    ESCAPE = 0x1005,
    LEFT = 0x2000,
    RIGHT = 0x2001,
    UP = 0x2002,
    DOWN = 0x2003
}

for i = 0, 255 do
    local r, g, b

    if i < 16 then
        local colors = {
            {0x00, 0x00, 0x00}, {0x00, 0x00, 0xAA}, {0x00, 0xAA, 0x00}, {0x00, 0xAA, 0xAA},
            {0xAA, 0x00, 0x00}, {0xAA, 0x00, 0xAA}, {0xAA, 0x55, 0x00}, {0xAA, 0xAA, 0xAA},
            {0x55, 0x55, 0x55}, {0x55, 0x55, 0xFF}, {0x55, 0xFF, 0x55}, {0x55, 0xFF, 0xFF},
            {0xFF, 0x55, 0x55}, {0xFF, 0x55, 0xFF}, {0xFF, 0xFF, 0x55}, {0xFF, 0xFF, 0xFF}
        }
        r, g, b = unpack(colors[i + 1])
    elseif i < 232 then
        local base = i - 16
        r = math.floor(base / 36) * 51
        g = (math.floor(base / 6) % 6) * 51
        b = (base % 6) * 51
    else 
        local gray = (i - 232) * 10 + 8
        r, g, b = gray, gray, gray
    end

    vga_to_rgb[i] = {r/255, g/255, b/255}
end

FrameBufferTestMixin = {}

function FrameBufferTestMixin:OnLoad()
    self.ScreenWidth = 320
    self.ScreenHeight = 50
   
    self:SetToplevel(true)
    -- self:SetIsFrameBuffer(true)
    self:SetAlpha(1)
    self:SetSize(self.ScreenWidth * 2, self.ScreenHeight * 2)
   
    self.FrameBuffer = {}

    for i = 0, self.ScreenHeight-1 do
        for j = 0, self.ScreenWidth-1 do
            local pixel = self:CreateTexture()
            pixel:SetColorTexture(0, 0, 0)
            pixel:SetSize(2, 2)
            pixel:SetDrawLayer("ARTWORK", 1)
            table.insert(self.FrameBuffer, pixel)
        end
    end

    local initialAnchor = AnchorUtil.CreateAnchor("TOPLEFT", self, "TOPLEFT", 0, 0)
    local layout = AnchorUtil.CreateGridLayout(GridLayoutMixin.Direction.TopLeftToBottomRight, self.ScreenWidth, 0, 0)
    AnchorUtil.GridLayout(self.FrameBuffer, initialAnchor, layout)
end

FrameBufferTestFrameParted = {}

for i = 1, 4 do
    local PartFrame = Mixin(CreateFrame("Frame", nil, UIParent), FrameBufferTestMixin)
    PartFrame:OnLoad()
    PartFrame:SetPoint("CENTER", 0, -150 + i * 100)
    PartFrame:Hide()
    table.insert(FrameBufferTestFrameParted, PartFrame)
end

function FrameOnKeyDown(event, key)
    print(string.format("key down (%s)", key))
    if RV32_KEYMAP[key] ~= nil then
        RiscVCore.pressed_keys[RV32_KEYMAP[key]] = true
    end
end

function FrameOnKeyUp(event, key)
    print(string.format("key up (%s)", key))
    if RV32_KEYMAP[key] ~= nil then
        RiscVCore.pressed_keys[RV32_KEYMAP[key]] = false
    end
end

FrameBufferTestFrameParted[1]:EnableKeyboard(true)
FrameBufferTestFrameParted[1]:SetScript("OnKeyDown", FrameOnKeyDown)
FrameBufferTestFrameParted[1]:SetScript("OnKeyUp", FrameOnKeyUp)


function GetPixel(x, y)
    local PartHeight = 50
    local PartN = 4 - math.floor(y / PartHeight)
    local localy = y % PartHeight
    return FrameBufferTestFrameParted[PartN].FrameBuffer[localy * 320 + x + 1]
end

function RenderFrame(CPU, framebuffer_addr)
    local PartHeight = 50

    for x = 0, 320-1 do
        for y = 0, 200-1 do
            local offset = y * 320 + x
            local data = CPU.memory:Read(framebuffer_addr + offset, 1)
            
            local color = vga_to_rgb[data]
            local pixel = GetPixel(x, y)
            pixel:SetColorTexture(unpack(color))
        end
    end
end

function ToggleWindow()
    for i = 1, 4 do
        FrameBufferTestFrameParted[i]:Show()
    end
end

local function callback()
    local PartHeight = 50

    for i = 0, 320-1 do
        for j = 0, 200-1 do
            local color = vga_to_rgb[test_frame[j*320 + i + 1]]
            local pixel = GetPixel(i, j)
            pixel:SetColorTexture(unpack(color))
        end
    end

    -- RunNextFrame(callback)
end

local function callback2()
    ToggleWindow()

    C_Timer.After(2, callback2)
end


-- RunNextFrame(callback)
-- RunNextFrame(callback2)