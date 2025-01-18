const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const mines = @import("minesweeper.zig");

pub fn main() !void {
    var game = mines.Minesweeper(18, 18).init();
    const win_width: c_int = @intCast((game.width - 1) * 40 + 70);
    const win_height: c_int = @intCast((game.height - 1) * 40 + 70);

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
            const localX = 20 + 40 * x;
            const localY = 20 + 40 * y;
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
    r.DrawText(text, @intCast(x + 2), @intCast(y + 2), 24, r.BLACK);
    r.DrawText(text, @intCast(x), @intCast(y), 24, color);
}

fn renderButton(x: usize, y: usize, hidden: bool) void {
    const mouseX = r.GetMouseX();
    const mouseY = r.GetMouseY();
    const is_mouseover = mouseX >= x and mouseX <= x + 30 and mouseY >= y and mouseY <= y + 30;

    const color = if (!hidden) r.BROWN else if (is_mouseover) r.BEIGE else r.GRAY;
    rect(@intCast(x), @intCast(y), 30, 30, 2, r.BLACK, color);
}

fn interactGame(game: anytype) !mines.MoveResult {
    const mX = r.GetMouseX();
    const mY = r.GetMouseY();
    const left = r.IsMouseButtonReleased(r.MOUSE_BUTTON_LEFT);
    const right = r.IsMouseButtonReleased(r.MOUSE_BUTTON_RIGHT);

    // Nothing to do if no buttons were pressed
    if (!left and !right) return undefined;

    // Constrain interaction events to the game board.
    // The minimum here prevents an underflow with usize (<20 - 20)
    if (mX <= 20 or mY <= 20 or mX > game.width * 40 + 30 or mY > game.height * 40 + 30) return undefined;

    // Convert from screen coords to the game board
    const gameX: usize = @intCast(@divFloor(mX - 20, 40));
    const gameY: usize = @intCast(@divFloor(mY - 20, 40));

    // If the click happened beyond the edge of the game board
    if (mX > gameX * 40 + 51 or mY > gameY * 40 + 51) return undefined;

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
