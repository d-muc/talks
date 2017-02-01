#!/usr/bin/env rdmd
import std.stdio;

void measure(alias fun)(uint iterations=100) {
    import std.datetime;

    StopWatch sw = AutoStart.yes;
    for (uint i=0; i<iterations; i++)
        fun();
    sw.stop;
    stdout.writefln("  %s nsecs", sw.peek.to!("nsecs", real) / iterations);
}

void main(string[] args)
{
    import std.bitmanip;

    struct FileInfo {
        uint fileSize;
        uint fileModifications;
        bool isDirectory;
    }
    struct NearlySameFileInfo {
        mixin(bitfields!(
            uint, "fileSize", ulong.sizeof-3-1,
            uint, "fileModifications", 3,
            bool, "isDirectory", 1
        ));
    }

    stdout.writeln(`
Using less space for the same information:
Pointers just require 42 Bit out of 64.
Bools require 1 Bit out of 64 Bit
A cacheline is 64 Byte. Maximize the information containing in one cacheline.
`);
    stdout.writefln("Original: %s bytes", FileInfo.sizeof);
    stdout.writefln("Original: %s bytes", NearlySameFileInfo.sizeof);

    FileInfo ff;
    ff.fileSize = 123;

    NearlySameFileInfo ff2;
    ff2.fileSize = 12;
}
