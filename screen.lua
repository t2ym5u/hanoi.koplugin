local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

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

Tap a peg to pick up its top disk (the peg is shaded), then tap another peg to drop it there. Tap the same peg again to put the disk back.

Rules:
• Only one disk may be moved at a time.
• Each move takes the top disk of one peg and places it on top of another peg.
• A larger disk may never be placed on top of a smaller disk.

The minimum number of moves to solve n disks is 2ⁿ − 1.
]])

local GAME_RULES_FR = [[
Tours de Hanoï — Règles

Déplacez tous les disques de la première tige vers la dernière.

Appuyez sur une tige pour prendre son disque supérieur (la tige est grisée), puis sur une autre tige pour l'y déposer. Appuyez à nouveau sur la même tige pour reposer le disque.

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
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Towers of Hanoi"), function()
        return {
            { text = _("New game"),            callback = function() self:onNewGame() end },
            { text = self:getSizeButtonText(), callback = function() self:openSizeMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    -- Tapping the pegs is the only move: no action bar while
    -- playing. Once the round is over, a "New game" bar appears under the status.
    self.status_text:setMaxWidth(self:getControlsWidth())
    local bar = self:buildActionBar({})
    local controls = VerticalGroup:new{ align = "center", self.status_text }
    if bar.round_over then
        table.insert(controls, VerticalSpan:new{ width = Size.span.vertical_large })
        table.insert(controls, bar)
    end

    -- Fill the width, but cap the
    -- height at 11/10 of it so a tall portrait budget doesn't stretch the rods.
    local frame_pad   = Size.padding.large
    local frame_extra = 2 * (frame_pad + Size.border.window)
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    local board_max_w = math.max(budget_w - frame_extra, 80)
    local board_max_h = math.max(math.min(budget_h - frame_extra, math.floor(board_max_w * 1.1)), 80)

    self.board_widget = HanoiBoardWidget:new{
        board      = self.board,
        max_width  = board_max_w,
        max_height = board_max_h,
        on_peg_tap = function(p) self:onPegTap(p) end,
    }
    local board_frame = FrameContainer:new{
        padding = frame_pad,
        margin  = 0,
        self.board_widget,
    }

    if is_landscape then
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
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
    self:refreshActionBar()
end

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------

function HanoiScreen:isRoundOver()
    return self.board.won and true or false
end

-- The bar only exists once the round is over, so showing or hiding it
-- reflows the layout instead of swapping the bar in place.
function HanoiScreen:refreshActionBar()
    if self.action_bar and self:isRoundOver() ~= self.action_bar.round_over then
        self:buildLayout()
        UIManager:setDirty(self, function() return "ui", self.dimen end)
    end
end

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
        title     = _("Size"),
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
        -- The selected peg is shaded on the board, so it isn't repeated here.
        local b = self.board
        status = self:joinStatus(T(_("%1 disks"), b.num_disks),
            T(_("Moves: %1"), b.moves),
            T(_("Optimal: %1"), b.optimal))
    end
    ScreenBase.updateStatus(self, status)
end

function HanoiScreen:getSizeButtonText()
    local n = self.plugin:getSetting("num_disks", 3)
    return T(_("Size: %1"), T(_("%1 disks"), n))
end

return HanoiScreen
