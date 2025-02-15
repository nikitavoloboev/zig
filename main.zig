const std = @import("std");

const c = @cImport({
    @cInclude("sys/ptrace.h");
    @cInclude("sys/wait.h");
    @cInclude("sys/user.h"); // defines struct user_regs_struct for x86_64
    @cInclude("unistd.h");
});

// Manually define the ptrace constants (macros aren't auto-imported)
const PTRACE_ATTACH = 16;
const PTRACE_GETREGS = 12;
const PTRACE_DETACH = 17;

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();
    var argIter = std.process.args();

    // Get the program name.
    const progName = argIter.next() orelse {
        return error.InvalidArgs;
    };

    // Get the PID argument.
    const pid_str = argIter.next() orelse {
        try stdout.print("Usage: {s} <pid>\n", .{progName});
        return;
    };

    // Parse the PID from the command-line argument.
    const maybe_pid = std.fmt.parseInt(i32, pid_str, 10);
    const pid = maybe_pid catch |err| switch (err) {
        error.Overflow => {
            try stdout.print("PID value {s} is too large\n", .{pid_str});
            return;
        },
        error.InvalidCharacter => {
            try stdout.print("Invalid PID: {s}\n", .{pid_str});
            return;
        },
    };

    // Attach to the target process.
    if (c.ptrace(PTRACE_ATTACH, pid, 0, 0) != 0) {
        try stdout.print("Failed to attach to process {d}\n", .{pid});
        return;
    }
    try stdout.print("Attached to process {d}\n", .{pid});

    // Wait for the process to stop.
    var status: i32 = 0;
    if (c.waitpid(pid, &status, 0) < 0) {
        try stdout.print("waitpid failed for process {d}\n", .{pid});
        return;
    }
    try stdout.print("Process {d} stopped (status: {d})\n", .{ pid, status });

    // Retrieve the CPU registers of the target process.
    var regs: c.struct_user_regs_struct = undefined;
    if (c.ptrace(PTRACE_GETREGS, pid, 0, &regs) != 0) {
        try stdout.print("Failed to get registers for process {d}\n", .{pid});
        return;
    }

    // Print selected registers (for x86_64).
    try stdout.print("Registers for process {d}:\n", .{pid});
    try stdout.print("  RIP: 0x{X}\n", .{regs.rip});
    try stdout.print("  RSP: 0x{X}\n", .{regs.rsp});
    try stdout.print("  RBP: 0x{X}\n", .{regs.rbp});
    try stdout.print("  RAX: 0x{X}\n", .{regs.rax});
    try stdout.print("  RBX: 0x{X}\n", .{regs.rbx});
    try stdout.print("  RCX: 0x{X}\n", .{regs.rcx});
    try stdout.print("  RDX: 0x{X}\n", .{regs.rdx});

    // Detach from the process.
    if (c.ptrace(PTRACE_DETACH, pid, 0, 0) != 0) {
        try stdout.print("Failed to detach from process {d}\n", .{pid});
        return;
    }
    try stdout.print("Detached from process {d}\n", .{pid});
}
