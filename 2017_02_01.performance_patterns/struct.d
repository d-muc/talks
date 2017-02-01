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

class A {
    ulong a, b, c;
    void foo() {
        stdout.writeln("a");
    }
}

class B: A {}

struct C {
    byte a;

    void foo() {
        stdout.writeln("c");
    }
}

struct D {
    byte b;

    private C c;
    alias c this;
}


void main(string[] args)
{
    B b = new B();
    D d;
    stdout.writefln("b.sizeof: %s bytes", B.sizeof);
    stdout.writefln("c.sizeof: %s bytes", C.sizeof);
    stdout.writefln("d.sizeof: %s bytes", D.sizeof);

    b.foo;
    d.foo;
}
