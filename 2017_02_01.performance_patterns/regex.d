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

void main() {
    import std.stdio;
    import std.regex;

    enum PATTERN = r"it is \d+:\d+ o'clock";

    auto r = regex(PATTERN);
    auto r2 = ctRegex!PATTERN;

    stdout.writeln("Runtime Regular Expressions");
    measure!(() => "it is 10:00 o'clock".match(r) );
    stdout.writeln("Compiletime Regular Expressions");
    measure!(() => "it is 10:00 o'clock".match(r2) );
}
