const std = @import("std");
const fs = std.fs;
const elf = std.elf;
const Header = elf.Elf32_Ehdr;
const ProgramHeader = elf.Elf32_Phdr;
const SectionHeader = elf.Elf32_Shdr;
const FileData = []align(std.heap.page_size_min) u8;
const Machine = @import("Machine.zig");
const Cpu = @import("Cpu.zig");

pub fn loadElf(data: FileData, machine: *Machine) !void {
    const header: *const Header = @ptrCast(data);

    std.debug.assert(header.e_phentsize == @sizeOf(ProgramHeader));
    std.debug.assert(header.e_shentsize == @sizeOf(SectionHeader));

    const program_headers_bytes = data[header.e_phoff..][0..header.e_phnum*@sizeOf(ProgramHeader)];
    const program_headers: []const ProgramHeader = @ptrCast(@alignCast(program_headers_bytes));

    const section_headers_bytes = data[header.e_shoff..][0..header.e_shnum*@sizeOf(SectionHeader)];
    const section_headers: []const SectionHeader = @ptrCast(@alignCast(section_headers_bytes));
    const section_header_strs = sectionHeaderStrs(data, header, section_headers);
    _ = section_header_strs;

    for (program_headers) |phdr| {
        //std.debug.print("loaded {} bytes at 0x{x}\n", .{phdr.p_filesz, phdr.p_paddr});
        //std.debug.print("hex: {x}\n", .{data[phdr.p_offset..][0..phdr.p_filesz]});
        @memcpy(machine.ram[phdr.p_paddr..][0..phdr.p_filesz], data[phdr.p_offset..][0..phdr.p_filesz]);
    }

    machine.cpu.pc =  header.e_entry;
}

fn sectionHeaderStrs(data: FileData, header: *const Header, section_headers: []const SectionHeader) []const u8 {
    const section_header_strs_header  = &section_headers[header.e_shstrndx];
    return data[section_header_strs_header.sh_offset..][0..section_header_strs_header.sh_size];
}

pub fn loadElfFromPath(path: []const u8, machine: *Machine) !void {
    const data = try readFile(path);
    defer freeFile(data);
    try loadElf(data, machine);
}

pub fn readFile(path: []const u8) !FileData {
    var file = try std.fs.cwd().openFile(path, .{});
    const file_size = (try file.stat()).size;
    var reader = file.reader(&.{});
    const data = try reader.interface.readAlloc(std.heap.page_allocator, file_size);
    return @alignCast(data);
}

pub fn freeFile(data: FileData) void {
    std.heap.page_allocator.free(data);
}

test {
    var machine = try Machine.init(std.testing.allocator, 32);
    defer machine.deinit();
    try loadElfFromPath("zig-out/bin/basic", &machine);

    for (0..1000) |_| machine.cpu.exec();
}
