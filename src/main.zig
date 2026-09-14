const std = @import("std");
const build_options = @import("build_options");

const AVB_MAGIC = "AVB0";
const FLAGS_OFFSET: u64 = 123;
const DEFAULT_FLAGS: u8 = 3;
const VERSION = build_options.version;
const DEVELOPER = "Ditzzy";

fn printUsage(exe_name: []const u8) void {
    std.debug.print(
        \\vbmeta_patch {s}
        \\CLI tool to patch Android vbmeta image file to disable verification flags.
        \\
        \\Usage:
        \\  {s} [options] <filename>
        \\
        \\Options:
        \\  -o, --out <path>       Write output to a new file instead of patching in-place
        \\  -f, --flags <0-3>      Value to set the vbmeta flags to (default: 3)
        \\                           0 = verification + verity enabled
        \\                           1 = VERIFICATION_DISABLED
        \\                           2 = VERIFICATION_ERROR_IGNORED
        \\                           3 = VERIFICATION_DISABLED | VERIFICATION_ERROR_IGNORED
        \\  -v, --version          Show version information
        \\  -h, --help             Show this help message
        \\
    , .{ VERSION, exe_name });
}

fn printVersion() void {
    std.debug.print("vbmeta_patch {s}\nDeveloper: {s}\n", .{ VERSION, DEVELOPER });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    const exe_name = if (args.len > 0) args[0] else "vbmeta_patcher";

    if (args.len <= 1) {
        printUsage(exe_name);
        std.process.exit(1);
    }

    var input_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var flags_value: u8 = DEFAULT_FLAGS;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage(exe_name);
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            printVersion();
            return;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--out")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("[ERROR] Option {s} requires an argument.\n", .{arg});
                std.process.exit(1);
            }
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--flags")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("[ERROR] Option {s} requires an argument.\n", .{arg});
                std.process.exit(1);
            }
            const parsed = std.fmt.parseInt(u8, args[i], 10) catch {
                std.debug.print("[ERROR] Invalid value for {s}: '{s}' (must be a number 0-3)\n", .{ arg, args[i] });
                std.process.exit(1);
            };
            if (parsed > 3) {
                std.debug.print("[ERROR] Invalid value for {s}: '{s}' (must be 0, 1, 2, or 3)\n", .{ arg, args[i] });
                std.process.exit(1);
            }
            flags_value = parsed;
        } else if (input_file == null) {
            input_file = arg;
        } else {
            std.debug.print("[ERROR] Unknown or extra argument '{s}'\n", .{arg});
            printUsage(exe_name);
            std.process.exit(1);
        }
    }

    const input_path = input_file orelse {
        std.debug.print("[ERROR] Missing input vbmeta file.\n\n", .{});
        printUsage(exe_name);
        std.process.exit(1);
    };

    try patchVbmeta(io, input_path, output_file, flags_value);
}

fn patchVbmeta(io: std.Io, input_path: []const u8, output_path: ?[]const u8, flags_value: u8) !void {
    const cwd = std.Io.Dir.cwd();

    const target_path = if (output_path) |out_path| blk: {
        cwd.copyFile(input_path, cwd, out_path, io, .{}) catch |err| {
            std.debug.print("[ERROR] copying file '{s}' to '{s}': {s}\nExiting...\n", .{ input_path, out_path, @errorName(err) });
            std.process.exit(1);
        };
        break :blk out_path;
    } else input_path;

    var file = cwd.openFile(io, target_path, .{ .mode = .read_write }) catch |err| {
        std.debug.print("[ERROR] opening file '{s}': {s}\nFile not modified. Exiting...\n", .{ target_path, @errorName(err) });
        std.process.exit(1);
    };

    defer file.close(io);
    try validateAndPatch(io, &file, flags_value);

    std.debug.print("[SUCCESS] Patching successful! Flags set to {d}.\n", .{flags_value});
}

fn validateAndPatch(io: std.Io, file: *std.Io.File, flags_value: u8) !void {
    var magic_buf: [AVB_MAGIC.len]u8 = undefined;

    var read_buf: [1024]u8 = undefined;
    var r = file.reader(io, &read_buf);
    const bytes_read = r.interface.readSliceShort(&magic_buf) catch 0;

    if (bytes_read < AVB_MAGIC.len or !std.mem.eql(u8, &magic_buf, AVB_MAGIC)) {
        std.debug.print("[ERROR] The provided image is not a valid vbmeta image.\nFile not modified. Exiting...\n", .{});
        std.process.exit(1);
    }

    const flag_byte = [_]u8{flags_value};
    file.writePositionalAll(io, &flag_byte, FLAGS_OFFSET) catch {
        std.debug.print("[ERROR] Failed when patching the vbmeta image.\nExiting...\n", .{});
        std.process.exit(1);
    };
}
