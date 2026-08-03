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
