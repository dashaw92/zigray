const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const mines = @import("minesweeper.zig");

const WIDTH = 32;
const HEIGHT = 32;
const BIG = WIDTH >= 20 and HEIGHT >= 20;
const CELL_SIZE = if (BIG) 20 else 30;
const TEXT_SIZE = if (BIG) 14 else 24;

pub fn main() !void {
    var game = mines.Minesweeper(WIDTH, HEIGHT).init();
    const win_width: c_int = @intCast(game.width * (CELL_SIZE + 10) + 30);
    const win_height: c_int = @intCast(game.height * (CELL_SIZE + 10) + 30);

    r.InitWindow(win_width, win_height, "Minesweeper");
    r.SetTargetFPS(144);
    defer r.CloseWindow();

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        defer r.EndDrawing();

        r.ClearBackground(r.ORANGE);
        switch (try interactGame(&game)) {
            .hit_mine => game.reset(),
            else => {},
        }
        renderGame(&game);
    }
}

fn rect(x: i32, y: i32, w: i32, h: i32, stroke_width: i32, stroke: r.Color, fill: r.Color) void {
    r.DrawRectangle(x - stroke_width, y - stroke_width, w + (stroke_width * 2), h + (stroke_width * 2), stroke);
    r.DrawRectangle(x, y, w, h, fill);
}

fn renderGame(game: anytype) void {
    rect(5, 5, r.GetScreenWidth() - 10, r.GetScreenHeight() - 10, 3, r.BLACK, r.DARKGRAY);
    for (0..game.height) |y| {
        for (0..game.width) |x| {
            const localX = 20 + (CELL_SIZE + 10) * x;
            const localY = 20 + (CELL_SIZE + 10) * y;
            const cell = game.cells[y * game.width + x];

            if (cell.isFlagged()) {
                renderButton(localX, localY, cell.isHidden());
                drawText("?", localX + 10, localY + 5, r.RED);
                continue;
            }

            switch (cell) {
                .mine => renderButton(localX, localY, cell.isHidden()),
                .empty => |e| {
                    renderButton(localX, localY, e.hidden);
                    if (!e.hidden) {
                        drawText(nearbyToStr(e.nearby), localX + 10, localY + 5, nearbyToColor(e.nearby));
                    }
                },
            }
        }
    }
}

fn drawText(text: [*]const u8, x: usize, y: usize, color: r.Color) void {
    r.DrawText(text, @intCast(x + 2), @intCast(y + 2), TEXT_SIZE, r.BLACK);
    r.DrawText(text, @intCast(x), @intCast(y), TEXT_SIZE, color);
}

fn renderButton(x: usize, y: usize, hidden: bool) void {
    const mouseX = r.GetMouseX();
    const mouseY = r.GetMouseY();
    const is_mouseover = mouseX >= x and mouseX <= x + CELL_SIZE and mouseY >= y and mouseY <= y + CELL_SIZE;

    const color = if (!hidden) r.BROWN else if (is_mouseover) r.BEIGE else r.GRAY;
    rect(@intCast(x), @intCast(y), CELL_SIZE, CELL_SIZE, 2, r.BLACK, color);
}

fn interactGame(game: anytype) !mines.MoveResult {
    const mX: usize = @intCast(r.GetMouseX());
    const mY: usize = @intCast(r.GetMouseY());
    const left = r.IsMouseButtonReleased(r.MOUSE_BUTTON_LEFT);
    const right = r.IsMouseButtonReleased(r.MOUSE_BUTTON_RIGHT);

    // Nothing to do if no buttons were pressed
    if (!left and !right) return undefined;

    // Constrain interaction events to the game board.
    // The minimum here prevents an underflow with usize (<20 - 20)
    if (mX <= 20 or mY <= 20 or mX > (game.width * (CELL_SIZE + 10)) + 30 or mY > (game.height * (CELL_SIZE + 10)) + 30) return undefined;

    // Convert from screen coords to the game board
    const gameX: usize = @intCast(@divFloor(mX - 20, CELL_SIZE + 10));
    const gameY: usize = @intCast(@divFloor(mY - 20, CELL_SIZE + 10));

    // If the click happened beyond the edge of the game board
    if (mX > gameX * (CELL_SIZE + 10) + (CELL_SIZE + 21) or mY > gameY * (CELL_SIZE + 10) + (CELL_SIZE + 21)) return undefined;

    const pos: mines.Point = .{ .x = gameX, .y = gameY };
    const move = if (left) mines.Move{ .expose = pos } else mines.Move{ .flag = pos };
    return game.play(move);
}

fn nearbyToStr(nearby: usize) [*]const u8 {
    return switch (nearby) {
        0 => "",
        1 => "1",
        2 => "2",
        3 => "3",
        4 => "4",
        5 => "5",
        6 => "6",
        7 => "7",
        8 => "8",
        else => unreachable,
    };
}

fn nearbyToColor(nearby: usize) r.Color {
    return switch (nearby) {
        0 => r.WHITE,
        1 => r.SKYBLUE,
        2 => r.GREEN,
        3 => r.ORANGE,
        4 => r.DARKBLUE,
        5 => r.RED,
        6 => r.MAGENTA,
        7 => r.PURPLE,
        8 => r.BLACK,
        else => unreachable,
    };
}
