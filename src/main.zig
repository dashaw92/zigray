const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));

pub fn main() !void {
    r.InitWindow(640, 480, "Test");
    r.SetTargetFPS(144);
    defer r.CloseWindow();

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        defer r.EndDrawing();

        r.ClearBackground(r.RED);
    }
}
