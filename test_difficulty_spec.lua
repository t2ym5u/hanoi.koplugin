local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

-- Difficulty guarantees: the disk count is the level (3, 4, 5 disks, as in
-- screen.lua's size menu). The board's optimum is 2^n - 1, which is the true
-- shortest solution (breadth-first search over every position), the
-- recursive solution wins in exactly that many moves, and more disks need
-- more moves.
local DISK_SIZES = { 3, 4, 5 }

-- Fewest moves from all disks on peg 1 to all on peg 3, by BFS.
-- A position: pos[d] = peg of disk d (1 smallest), encoded base 3.
local function shortest(n)
    local function encode(pos)
        local k = 0
        for d = n, 1, -1 do k = k * 3 + (pos[d] - 1) end
        return k
    end
    local start, goal = {}, {}
    for d = 1, n do start[d], goal[d] = 1, 3 end
    local goal_key = encode(goal)
    local dist = { [encode(start)] = 0 }
    local queue, head = { start }, 1
    while head <= #queue do
        local pos = queue[head]; head = head + 1
        local k = encode(pos)
        if k == goal_key then return dist[k] end
        -- top disk of each peg = the smallest disk on it
        local top = {}
        for d = n, 1, -1 do top[pos[d]] = d end
        for from = 1, 3 do
            local d = top[from]
            if d then
                for to = 1, 3 do
                    if to ~= from and (not top[to] or top[to] > d) then
                        local nxt = {}
                        for i = 1, n do nxt[i] = pos[i] end
                        nxt[d] = to
                        local nk = encode(nxt)
                        if not dist[nk] then
                            dist[nk] = dist[k] + 1
                            queue[#queue + 1] = nxt
                        end
                    end
                end
            end
        end
    end
end

describe("Hanoi difficulty", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    -- The classic recursive solution: exactly 2^n - 1 moves.
    local function solve(b, n, from, to, via)
        if n == 0 then return end
        solve(b, n - 1, from, via, to)
        b:selectPeg(from); b:selectPeg(to)
        solve(b, n - 1, via, to, from)
    end

    for _, n in ipairs(DISK_SIZES) do
        it("is true for a win in 2^n - 1 moves (" .. n .. " disks)", function()
            local b = Board:new({ num_disks = n })
            assert.is_false(b:isPerfect())
            solve(b, n, 1, 3, 2)
            assert.is_true(b.won)
            assert.are.equal(2 ^ n - 1, b.moves)
            assert.is_true(b:isPerfect())
        end)
    end

    it("the optimum is the true shortest solution, and grows with the disks", function()
        local prev = 0
        for _, n in ipairs(DISK_SIZES) do
            local b = Board:new({ num_disks = n })
            assert.are.equal(shortest(n), b.optimal, n .. " disks")
            assert.is_true(b.optimal > prev, n .. " disks")
            prev = b.optimal
        end
    end)
end)
