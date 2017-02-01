#!/usr/bin/env rdmd
import std.algorithm, std.range, std.stdio;

uint[] primes(uint max) {
  return iota(1, max).filter!isPrime.array;
}

// Algorithm from https://en.wikipedia.org/wiki/Primality_test
bool isPrime(uint n) {
  if (n <= 3) return n > 1;
  if (n % 2 == 0 || n % 3 == 0) return false;
  uint i = 5;
  while (i*i <= n) {
    if (n % i == 0 || n % (i + 2) == 0) return false;
    i += 6;
  }
  return true;
}

unittest {
 assert(2.isPrime);
 assert(11.isPrime);
 assert(!12.isPrime);
 assert(97.isPrime);
}

void main() {
  enum a = primes(10000);
  stdout.writefln("compile time primes %s", a);
}
