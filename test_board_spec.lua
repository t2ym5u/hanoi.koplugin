local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

describe("HanoiBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    describe("new", function()
        it("stacks all disks on peg 1, largest at the bottom", function()
            local b = Board:new({ num_disks = 3 })
            assert.are.same({ 3, 2, 1 }, b.pegs[1])
            assert.are.same({}, b.pegs[2])
            assert.are.same({}, b.pegs[3])
            assert.are.equal(7, b.optimal)  -- 2^3 - 1
        end)
    end)

    describe("selectPeg", function()
        it("selects a non-empty peg", function()
            local b = Board:new({ num_disks = 3 })
            assert.are.equal("selected", b:selectPeg(1))
            assert.are.equal(1, b.selected_peg)
        end)

        it("selecting the same peg again deselects it", function()
            local b = Board:new({ num_disks = 3 })
            b:selectPeg(1)
            assert.are.equal("deselected", b:selectPeg(1))
            assert.is_nil(b.selected_peg)
        end)

        it("moves the top disk to an empty destination peg", function()
            local b = Board:new({ num_disks = 3 })
            b:selectPeg(1)
            assert.are.equal("moved", b:selectPeg(2))
            assert.are.same({ 3, 2 }, b.pegs[1])
            assert.are.same({ 1 }, b.pegs[2])
            assert.are.equal(1, b.moves)
        end)

        it("refuses to place a larger disk onto a smaller one", function()
            local b = Board:new({ num_disks = 3 })
            b:selectPeg(1); b:selectPeg(2)  -- disk 1 -> peg 2
            b:selectPeg(1)                  -- select peg 1 (top disk 2)
            assert.are.equal("invalid", b:selectPeg(2))
            assert.are.same({ 1 }, b.pegs[2])
        end)

        it("solves a 1-disk tower in a single move", function()
            local b = Board:new({ num_disks = 1 })
            b:selectPeg(1)
            assert.are.equal("won", b:selectPeg(3))
            assert.is_true(b.won)
        end)
    end)

    describe("isPerfect", function()
        -- The classic recursive solution: exactly 2^n - 1 moves.
        local function solve(b, n, from, to, via)
            if n == 0 then return end
            solve(b, n - 1, from, via, to)
            b:selectPeg(from); b:selectPeg(to)
            solve(b, n - 1, via, to, from)
        end

        for _, n in ipairs({ 3, 4, 5 }) do
            it("is true for a win in 2^n - 1 moves (" .. n .. " disks)", function()
                local b = Board:new({ num_disks = n })
                assert.is_false(b:isPerfect())
                solve(b, n, 1, 3, 2)
                assert.is_true(b.won)
                assert.are.equal(2 ^ n - 1, b.moves)
                assert.is_true(b:isPerfect())
            end)
        end

        it("is false for a win with extra moves, and survives a save", function()
            local b = Board:new({ num_disks = 3 })
            b:selectPeg(1); b:selectPeg(2)   -- smallest disk away...
            b:selectPeg(2); b:selectPeg(1)   -- ...and back: 2 wasted moves
            solve(b, 3, 1, 3, 2)
            assert.is_true(b.won)
            assert.are.equal(9, b.moves)
            assert.is_false(b:isPerfect())

            local p = Board:new({ num_disks = 3 })
            solve(p, 3, 1, 3, 2)
            local p2 = Board:new()
            assert.is_true(p2:load(p:serialize()))
            assert.is_true(p2:isPerfect())
        end)
    end)

    describe("serialize / load", function()
        it("round-trips peg contents and move count", function()
            local b = Board:new({ num_disks = 3 })
            b:selectPeg(1); b:selectPeg(2)
            local data = b:serialize()

            local b2 = Board:new({ num_disks = 3 })
            assert.is_true(b2:load(data))
            assert.are.same(b.pegs[1], b2.pegs[1])
            assert.are.same(b.pegs[2], b2.pegs[2])
            assert.are.equal(b.moves, b2.moves)
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
