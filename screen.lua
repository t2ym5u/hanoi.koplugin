local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local ScreenBase        = require("screen_base")
local MenuHelper        = require("menu_helper")
local HanoiBoard        = lrequire("board")
local HanoiBoardWidget  = lrequire("board_widget")

local DeviceScreen = Device.screen

local DISK_SIZES = { 3, 4, 5 }

local GAME_RULES_EN = _([[
Tower of Hanoi — Rules

Move all disks from the first peg to the last peg.

Rules:
• Only one disk may be moved at a time.
• Each move takes the top disk of one peg and places it on top of another peg.
• A larger disk may never be placed on top of a smaller disk.

The minimum number of moves to solve n disks is 2ⁿ − 1.
]])

local GAME_RULES_FR = [[
Tours de Hanoï — Règles

Déplacez tous les disques de la première tige vers la dernière.

Règles :
• Un seul disque peut être déplacé à la fois.
• Chaque déplacement consiste à prendre le disque supérieur d'une tige et à le placer sur le dessus d'une autre tige.
• Un disque plus grand ne peut jamais être posé sur un disque plus petit.

Le nombre minimum de déplacements pour résoudre n disques est 2ⁿ − 1.
]]

local HanoiScreen = ScreenBase:extend{}

function HanoiScreen:init()
    local state     = self.plugin:loadState()
    local num_disks = self.plugin:getSetting("num_disks", 3)
    self.board = HanoiBoard:new{ num_disks = num_disks }
    if not self.board:load(state) then
        -- new board already ready
    end
    ScreenBase.init(self)
end

function HanoiScreen:serializeState()
    return self.board:serialize()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function HanoiScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 100)
        or  math.floor(sw * 0.9)

    local title_bar = self:buildTitleBar(_("Towers of Hanoi"), function()
        return {
            { text = _("New game"),            callback = function() self:onNewGame() end },
            { text = self:getSizeButtonText(), callback = function() self:openSizeMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    local margin      = Size.margin.default
    local padding     = Size.padding.large
    local frame_extra = (padding + margin) * 2

    local board_max_w, board_max_h
    if is_landscape then
        board_max_w = math.floor(sw * 0.55)
        board_max_h = sh - frame_extra - 20
    else
        board_max_w = sw - frame_extra
        board_max_h = sh - 60 - 30 - frame_extra * 2 - 40
    end
    board_max_w = math.max(board_max_w, 80)
    board_max_h = math.max(board_max_h, 80)

    self.board_widget = HanoiBoardWidget:new{
        board      = self.board,
        max_width  = board_max_w,
        max_height = board_max_h,
        on_peg_tap = function(p) self:onPegTap(p) end,
    }

    local board_frame = FrameContainer:new{
        padding = padding,
        margin  = margin,
        self.board_widget,
    }

    self.status_text:setMaxWidth(is_landscape and btn_width or (board_max_w + frame_extra))

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            self.status_text,
        }
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        local content = VerticalGroup:new{
            align = "center",
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self:buildPortraitLayout(title_bar, content, nil)
    end
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Peg interaction
-- ---------------------------------------------------------------------------

function HanoiScreen:onPegTap(p)
    local result = self.board:selectPeg(p)
    self.board_widget:refresh()
    if result == "won" then
        local b = self.board
        self:updateStatus(T(_("Congratulations! %1 moves (optimal: %2)"), b.moves, b.optimal))
    elseif result == "invalid" then
        self:updateStatus(_("Invalid move."))
    else
        self:updateStatus()
    end
    self.plugin:saveState(self.board:serialize())
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function HanoiScreen:onNewGame()
    local nd = self.plugin:getSetting("num_disks", 3)
    self.board = HanoiBoard:new{ num_disks = nd }
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function HanoiScreen:openSizeMenu()
    local sizes = {}
    for idx, n in ipairs(DISK_SIZES) do
        sizes[#sizes + 1] = {
            id   = n,
            text = T(_("%1 disks"), n),
        }
    end
    MenuHelper.openSizeMenu{
        title     = _("Select disk count"),
        sizes     = sizes,
        current   = self.plugin:getSetting("num_disks", 3),
        parent    = self,
        on_select = function(id)
            self.plugin:saveSetting("num_disks", id)
            if self.size_btn then
                self.size_btn:setText(self:getSizeButtonText(), self.size_btn.width)
            end
            self:onNewGame()
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function HanoiScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        local b = self.board
        status = T(_("Congratulations! %1 moves (optimal: %2)"), b.moves, b.optimal)
    else
        local b = self.board
        status = T(_("Moves: %1 / Optimal: %2"), b.moves, b.optimal)
        if b.selected_peg then
            status = status .. T(_(" — Peg %1 selected"), ({ "A", "B", "C" })[b.selected_peg])
        end
    end
    ScreenBase.updateStatus(self, status)
end

function HanoiScreen:getSizeButtonText()
    local n = self.plugin:getSetting("num_disks", 3)
    return T(_("%1 disks"), n)
end

return HanoiScreen
