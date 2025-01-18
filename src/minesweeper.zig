const std = @import("std");
const Random = std.Random;
const Fifo = std.fifo.LinearFifo;

pub fn Minesweeper(comptime _width: comptime_int, comptime _height: comptime_int) type {
    const Game = struct {
        const Self = @This();

        width: usize,
        height: usize,
        cells: [_width * _height]Cell = undefined,
        lost: bool = false,
        minesPlaced: bool = false,
        rng: Random,

        pub fn init() Self {
            var xor = Random.DefaultPrng.init(@intCast(std.time.timestamp()));
            const rng = xor.random();

            var self: Self = .{
                .width = _width,
                .height = _height,
                .rng = rng,
            };

            inline for (self.cells, 0..) |_, i| {
                self.cells[i] = Cell{ .empty = .{} };
            }

            return self;
        }

        pub fn reset(self: *Self) void {
            inline for (self.cells, 0..) |_, i| {
                self.cells[i] = Cell{ .empty = .{} };
            }

            self.minesPlaced = false;
            self.lost = false;
        }

        fn inBounds(self: *Self, pt: *const Point) bool {
            return pt.x >= 0 and pt.x < self.width and pt.y >= 0 and pt.y < self.height;
        }

        fn neighbors(x: usize, y: usize) [8]?Point {
            return [8]?Point{
                if (x == 0 or y == 0) null else .{ .x = x - 1, .y = y - 1 },
                .{ .x = x + 1, .y = y + 1 },
                if (x == 0) null else .{ .x = x - 1, .y = y + 1 },
                if (y == 0) null else .{ .x = x + 1, .y = y - 1 },
                if (y == 0) null else .{ .x = x, .y = y - 1 },
                .{ .x = x, .y = y + 1 },
                if (x == 0) null else .{ .x = x - 1, .y = y },
                .{ .x = x + 1, .y = y },
            };
        }

        fn placeMines(self: *Self, avoid_x: usize, avoid_y: usize) void {
            const needed_mines = self.height + (self.width / 2);
            var num_mines: u8 = 0;
            var i: usize = 0;
            while (num_mines < needed_mines) : (i += 1) {
                if (i >= (self.width * self.height)) i = 0;

                const x = i % self.width;
                const y = i / self.width;

                // Do not place a mine at the specific coords- this position
                // is the starting move, and placing a mine here would be
                // really annoying for the player.
                if (x == avoid_x and y == avoid_y) continue;
                // Already a mine here
                if (!self.cells[i].isEmpty()) continue;
                // Give a large chance to not place a mine in an attempt to distribute them
                // evenly.
                if (self.rng.float(f32) <= 0.9) continue;

                num_mines += 1;
                self.cells[i] = Cell{ .mine = false };
            }

            //Update nearby mine count for all empty cells.
            for (self.cells, 0..) |_, j| {
                const x = j % self.width;
                const y = j / self.width;
                var cell = &self.cells[j];
                //If we're on a mine, obviously nothing to do
                if (!cell.isEmpty()) continue;

                const neighborsOf = neighbors(x, y);

                var nearby: usize = 0;
                for (neighborsOf) |point| {
                    if (point == null) continue;
                    if (!self.inBounds(&point.?)) continue;
                    const neighbor = self.cells[point.?.y * self.width + point.?.x];
                    if (!neighbor.isEmpty()) nearby += 1;
                }

                switch (cell.*) {
                    .empty => |*e| e.nearby = nearby,
                    else => unreachable,
                }
            }
        }

        pub fn play(self: *Self, move: Move) !MoveResult {
            if (!self.inBounds(&move.position())) {
                return MoveResult{ .out_of_bounds = move.position() };
            }
            const x = move.position().x;
            const y = move.position().y;
            const cell: *Cell = &self.cells[y * self.width + x];
            switch (move) {
                .flag => {
                    switch (cell.*) {
                        .mine => |*mine| mine.* = !mine.*,
                        .empty => |*empty| {
                            if (cell.isHidden()) empty.flagged = !empty.flagged;
                        },
                    }
                    return .success;
                },
                .expose => {
                    switch (cell.*) {
                        .mine => {
                            self.lost = true;
                            return MoveResult{ .hit_mine = move.position() };
                        },
                        .empty => |*empty| {
                            empty.hidden = false;
                            if (!self.minesPlaced) {
                                self.placeMines(x, y);
                                self.minesPlaced = true;
                            }

                            if (empty.nearby == 0) {
                                for (&self.cells) |*c| {
                                    c.setVisited(false);
                                }

                                // floodfill nearby cells to expose all until
                                // all trivial cells are exposed.
                                var queue = Fifo(Point, .{ .Static = _width * _height }).init();
                                defer queue.deinit();

                                try queue.writeItem(move.position());
                                cell.setVisited(true);
                                while (queue.count != 0) {
                                    const pos = queue.readItem().?;
                                    var currentCell = &self.cells[pos.y * self.width + pos.x];

                                    if (!currentCell.isEmpty()) continue;
                                    currentCell.setHidden(false);
                                    if (currentCell.nearbyMines() > 0) continue;

                                    for (neighbors(pos.x, pos.y)) |neighbor| {
                                        if (neighbor == null) continue;
                                        if (!self.inBounds(&neighbor.?)) continue;
                                        const neighborCell = &self.cells[neighbor.?.y * self.width + neighbor.?.x];
                                        if (neighborCell.isVisited()) continue;
                                        neighborCell.setVisited(true);

                                        try queue.writeItem(neighbor.?);
                                    }
                                }
                            }
                        },
                    }
                    return .success;
                },
            }
        }
    };

    return Game;
}

pub const Cell = union(enum) {
    mine: bool,
    empty: EmptyCell,

    pub fn setHidden(cell: *Cell, h: bool) void {
        switch (cell.*) {
            .mine => return,
            .empty => |*e| e.hidden = h,
        }
    }

    pub fn isVisited(cell: *const Cell) bool {
        return switch (cell.*) {
            .mine => true,
            .empty => |e| e.visited,
        };
    }

    pub fn setVisited(cell: *Cell, v: bool) void {
        switch (cell.*) {
            .mine => return,
            .empty => |*e| e.visited = v,
        }
    }

    pub fn isFlagged(cell: *const Cell) bool {
        return switch (cell.*) {
            .mine => |m| m,
            .empty => |e| e.flagged,
        };
    }

    pub fn isEmpty(cell: *const Cell) bool {
        return switch (cell.*) {
            .mine => false,
            .empty => true,
        };
    }

    pub fn isHidden(cell: *const Cell) bool {
        return switch (cell.*) {
            .mine => true,
            .empty => |empty| empty.hidden,
        };
    }

    pub fn nearbyMines(cell: *const Cell) usize {
        return switch (cell.*) {
            .mine => 0,
            .empty => |empty| empty.nearby,
        };
    }
};

pub const EmptyCell = struct {
    flagged: bool = false,
    hidden: bool = true,
    visited: bool = false,
    nearby: usize = 0,
};

pub const Point = struct {
    x: usize,
    y: usize,
};

pub const Move = union(enum) {
    flag: Point,
    expose: Point,

    pub fn position(move: *const Move) Point {
        return switch (move.*) {
            .flag => |f| f,
            .expose => |e| e,
        };
    }
};

pub const MoveResult = union(enum) {
    success,
    out_of_bounds: Point,
    hit_mine: Point,
};
