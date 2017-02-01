#!/usr/bin/env rdmd

/** Fixed Length Sorting via Sorting Networks.

    See also: http://forum.dlang.org/post/ne5m62$1gu5$1@digitalmars.com
    See also: http://cpansearch.perl.org/src/JGAMBLE/Algorithm-Networksort-1.30/lib/Algorithm/Networksort.pm
    See also: http://www.angelfire.com/blog/ronz/Articles/999SortingNetworksReferen.html

    License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).

    TODO see some sizes are not supported, we should not have holes.
    Use http://www.angelfire.com/blog/ronz/Articles/999SortingNetworksReferen.html

    TODO Sometimes the sort routine gets too bulky. Suggestion: also define
    networks for `medianOfUpTo` and `medianExactly`, then use them in a
    quicksort manner - first compute the median to segregate values in
    below/over the median, then make two calls to `sortExactly!(n / 2)`. That
    way you get to sort n values with median of n values (smaller and simpler)
    and two sorts of n / 2 values.

    TODO Stability of equal elements: Need template parameter `equalityStability`? Scalar builtin values are always stable.

    TODO There should be a notion of at what point the networks become too bulky
    to be fast - 6-16 may be the limit.

    TODO There is a nice peephole optimization you could make. Consider:

    r.conditionalSwap!("a < b", less, 0, 1, 1, 2)(r);

    which needs to do

    if (r[1] < r[0]) r.swapAt(0, 1);
    if (r[2] < r[1]) r.swapAt(1, 2);

    For types with no elaborate copy/assignment, it's more efficient to use a
    "hole"-based approach - assign the first element to a temporary and then
    consider it a hole that you fill, then leaving another hole:

    if (r[1] < r[0])
    if (r[2] < r[0]) r.swapAt(0, 1, 2);
    else r.swapAt(0, 1);
    else
    if (r[2] < r[1]) r.swapAt(1, 2);

    with swapAt with three argument having this definition:

    auto t = r[a]; r[a] = r[b]; r[b] = r[c]; r[c] = t;

    i.e. create a temporary (which creates a "hole" in the array) then fill it
    leaving another hole etc., until the last hole is filled with the temporary.
*/
module sortn;

import std.stdio;
import std.meta : allSatisfy;
import std.traits : isIntegral;
import std.range : isInputRange, isRandomAccessRange;

version(unittest) import std.algorithm.comparison : equal;

/** Static Iota.
    TODO Move to Phobos std.range.
*/
template iota(size_t from, size_t to)
    if (from <= to)
{
    alias iota = iotaImpl!(to - 1, from);
}
private template iotaImpl(size_t to, size_t now)
{
    import std.meta : AliasSeq;
    static if (now >= to) { alias iotaImpl = AliasSeq!(now); }
    else                  { alias iotaImpl = AliasSeq!(now, iotaImpl!(to, now + 1)); }
}

/** Conditionally pairwise sort elements of `Range` `r` at `indexes` using
    comparison predicate `less`.

    TODO Perhaps defines as

    template conditionalSwap(indexes...)
    {
       void conditionalSwap(less = "a < b", Range)(Range r)
       {
       }
    }

    instead.
 */
void conditionalSwap(alias less = "a < b", Range, indexes...)(Range r)
    if (isRandomAccessRange!Range &&
        allSatisfy!(isIntegral, typeof(indexes)) &&
        indexes.length &&
        (indexes.length & 1) == 0) // even number of indexes
{
    import std.algorithm.mutation : swapAt;
    import std.functional : binaryFun;
    foreach (const i; iota!(0, indexes.length / 2))
    {
        const j = indexes[2*i];
        const k = indexes[2*i + 1];

        static assert(j >= 0, "First part of index pair " ~ i.stringof ~ " is negative");
        static assert(k >= 0, "Second part of index pair " ~ i.stringof ~ " is negative");

        if (!binaryFun!less(r[j], r[k]))
        {
            r.swapAt(j, k);
        }
    }
}

/** Largest length supported by network sort `networkSortUpTo`. */
enum networkSortMaxLength = 22;

/** Sort at most the first `n` elements of `r` using comparison `less` using
    a networking sort.

    Note: Sorting networks are not unique, not even optimal solutions.

    See also: http://stackoverflow.com/questions/3903086/standard-sorting-networks-for-small-values-of-n
    See also: http://www.cs.brandeis.edu/~hugues/sorting_networks.html
 */
auto networkSortUpTo(uint n, alias less = "a < b", Range)(Range r)
    if (isRandomAccessRange!Range)
in
{
    assert(r.length >= n);
}
body
{
    auto s = r[0 .. n];

    static if (n < 2)
    {
        // already sorted
    }
    else static if (n == 2)
    {
        s.conditionalSwap!(less, Range, 0, 1);
    }
    else static if (n == 3)
    {
        s.conditionalSwap!(less, Range,
                           0,1,
                           1,2,
                           0,1);
    }
    else static if (n == 4)
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, // 2 in parallel
                           0,2, 1,3, // 2 in parallel
                           1,2);
    }
    else static if (n == 5)
    {
        s.conditionalSwap!(less, Range,
                           0,1, 3,4,  // 2 in parallel
                           0,2,
                           0,3, 1,2,  // 2 in parallel
                           2,3, 1,4,  // 2 in parallel
                           1,2, 3,4); // 2 in parallel
    }
    else static if (n == 6)
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, // 3 in parallel
                           0,2, 1,4, 3,5, // 3 in parallel
                           0,1, 2,3, 4,5, // 3 in parallel
                           1,2, 3,4,      // 2 in parallel
                           2,3);
    }
    else static if (n == 8)     // Bitonic Sorter. 6-steps: https://en.wikipedia.org/wiki/Bitonic_sorter
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7,
                           0,3, 4,7, 1,2, 5,6,
                           0,1, 2,3, 4,5, 6,7,
                           0,7, 1,6, 2,5, 3,4,
                           0,2, 1,3, 4,6, 5,7,
                           0,1, 2,3, 4,5, 6,7);
    }
    else static if (n == 9)     // R. W. Floyd.
    {
        s.conditionalSwap!(less, Range,
                           0,1, 3,4, 6,7,
                           1,2, 4,5, 7,8,
                           0,1, 3,4, 6,7,
                           0,3,
                           3,6,
                           0,3, 1,4,
                           4,7,
                           1,4, 2,5,
                           5,8,
                           1,3, 2,5,
                           2,6, 5,7,
                           4,6,
                           2,4,
                           2,3, 5,6);
    }
    else static if (n == 10)    // A. Waksman.
    {
        s.conditionalSwap!(less, Range,
                           0,5, 1,6, 2,7, 3,8, 4,9,
                           0,3, 1,4, 5,8, 6,9,
                           0,2, 3,6, 7,9,
                           0,1, 2,4, 5,7, 8,9,
                           1,2, 3,5, 4,6, 7,8,
                           1,3, 2,5, 4,7, 6,8,
                           2,3, 6,7,
                           3,4, 5,6,
                           4,5);
    }
    else static if (n == 11)    // 12-input by Shapiro and Green, minus the connections to a twelfth input.
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9,
                           0,2, 1,3, 4,6, 5,7, 8,10,
                           1,2, 5,6, 9,10,
                           1,5, 6,10,
                           2,6, 5,9,
                           0,4, 1,5, 6,10,
                           3,7, 4,8,
                           0,4,
                           1,4, 3,8, 7,10,
                           2,3, 8,9,
                           2,4, 3,5, 6,8, 7,9,
                           3,4, 5,6, 7,8);
    }
    else static if (n == 12)    // Shapiro and Green.
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11,
                           0,2, 1,3, 4,6, 5,7, 9,11, 8,10,
                           1,2, 5,6, 9,10,
                           1,5, 6,10,
                           2,6, 5,9,
                           0,4, 1,5, 6,10, 7,11,
                           3,7, 4,8,
                           0,4, 7,11,
                           1,4, 3,8, 7,10,
                           2,3, 8,9,
                           2,4, 3,5, 6,8, 7,9,
                           3,4, 5,6, 7,8);
    }
    else static if (n == 13)    // Generated by the END algorithm.
    {
        s.conditionalSwap!(less, Range,
                           0,12, 1,7, 2,6, 3,4, 5,8, 9,11,
                           0,1, 2,3, 4,6, 5,9, 7,12, 8,11,
                           0,2, 1,4, 3,7, 6,12, 7,8, 10,11,
                           4,9, 6,10, 11,12,
                           1,7, 3,4, 5,6, 8,9, 10,11,
                           1,3, 2,6, 4,7, 8,10, 9,11,
                           0,5, 2,5, 6,8, 9,10,
                           1,2, 3,5, 4,6, 7,8,
                           2,3, 4,5, 6,7, 8,9,
                           3,4, 5,6);
    }
    else static if (n == 14) // Green's construction for 16 inputs minus connections to the fifteenth and sixteenth inputs.
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13,
                           0,2, 1,3, 4,6, 5,7, 8,10, 9,11,
                           0,4, 1,5, 2,6, 3,7, 8,12, 9,13,
                           0,8, 1,9, 2,10, 3,11, 4,12, 5,13,
                           3,12, 5,10, 6,9,
                           1,2, 4,8, 7,11,
                           1,4, 2,8, 7,13,
                           2,4, 3,8, 5,6, 7,12, 9,10, 11,13,
                           3,5, 6,8, 7,9, 10,12,
                           3,4, 5,6, 7,8, 9,10, 11,12,
                           6,7, 8,9);
    }
    else static if (n == 15) // Green's construction for 16 inputs minus connections to the sixteenth input.
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13,
                           0,2, 1,3, 4,6, 5,7, 8,10, 9,11, 12,14,
                           0,4, 1,5, 2,6, 3,7, 8,12, 9,13, 10,14,
                           0,8, 1,9, 2,10, 3,11, 4,12, 5,13, 6,14,
                           3,12, 5,10, 6,9, 13,14,
                           1,2, 4,8, 7,11,
                           1,4, 2,8, 7,13, 11,14,
                           2,4, 3,8, 5,6, 7,12, 9,10, 11,13,
                           3,5, 6,8, 7,9, 10,12,
                           3,4, 5,6, 7,8, 9,10, 11,12,
                           6,7, 8,9);
    }
    else static if (n == 16) // Green's construction. TODO Use 10-step Bitonic sorter instead?
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13, 14,15,
                           0,2, 1,3, 4,6, 5,7, 8,10, 9,11, 12,14, 13,15,
                           0,4, 1,5, 2,6, 3,7, 8,12, 9,13, 10,14, 11,15,
                           0,8, 1,9, 2,10, 3,11, 4,12, 5,13, 6,14, 7,15,
                           3,12, 5,10, 6,9, 13,14,
                           1,2, 4,8, 7,11,
                           1,4, 2,8, 7,13, 11,14,
                           2,4, 3,8, 5,6, 7,12, 9,10, 11,13,
                           3,5, 6,8, 7,9, 10,12,
                           3,4, 5,6, 7,8, 9,10, 11,12,
                           6,7, 8,9);
    }
    else static if (n == 18) // Baddar's PHD thesis, chapter 6. Fewest stages but 2 comparators more than 'batcher'
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13, 14,15, 16,17,
                           0,2, 1,3, 4,6, 5,7, 8,10, 9,11, 12,17, 13,14, 15,16,
                           0,4, 1,5, 2,6, 3,7, 9,10, 8,12, 11,16, 13,15, 14,17,
                           0,8, 1,13, 2,4, 3,5, 6,17, 7,16, 9,15, 10,14, 11,12,
                           0,1, 2,11, 3,15, 4,10, 5,12, 6,13, 7,14, 8,9, 16,17,
                           1,8, 3,10, 4,15, 5,11, 6,9, 7,13, 14,16,
                           1,2, 3,6, 4,8, 5,9, 7,11, 10,13, 12,16, 14,15,
                           2,3, 5,8, 6,7, 9,10, 11,14, 12,13,
                           2,4, 3,5, 6,8, 7,9, 10,11, 12,14, 13,15,
                           3,4, 5,6, 7,8, 9,10, 11,12, 13,14,
                           4,5, 6,7, 8,9, 10,11, 12,13);
    }
    else static if (n == 22) // Baddar's PHD thesis, chapter 7. Fewest stages but 2 comparators more than 'batcher'
    {
        s.conditionalSwap!(less, Range,
                           0,1, 2,3, 4,5, 6,7, 8,9, 10,11, 12,13, 14,15, 16,17, 18,19, 20,21,
                           0,5, 1,3, 2,4, 6,8, 7,9, 10,12, 11,13, 14,16, 15,17, 18,20, 19,21,
                           6,10, 7,11, 8,12, 9,13, 14,18, 15,19, 16,20, 17,21,
                           0,2, 1,4, 3,5, 7,15, 8,16, 9,17, 11,19,
                           0,10, 1,18, 3,12, 5,20, 13,21,
                           0,7, 2,4, 3,15, 6,14, 9,18, 17,20,
                           0,6, 1,8, 2,11, 3,8, 4,16, 5,10, 12,19, 13,14, 20,21,
                           2,13, 4,7, 5,9, 10,15, 11,17, 12,18, 14,16, 16,20, 18,19,
                           1,3, 2,6, 4,5, 7,9, 8,13, 10,11, 12,14, 15,17, 19,20,
                           3,5, 4,6, 7,8, 9,13, 10,12, 11,14, 15,18, 16,17,
                           1,2, 5,10, 6,7, 8,9, 11,12, 13,15, 14,16, 18,19,

                           2,3, 5,7, 8,10, 9,11, 12,13, 14,15, 16,18, 17,19,
                           2,4, 3,6, 7,8, 9,10, 11,12, 13,14, 15,16, 17,18,
                           3,4, 5,6, 8,9, 10,11, 12,13, 14,15, 16,17,
                           4,5, 6,7);
    }
    else
    {
        static assert(false, "Unsupported n " ~ n.stringof);
    }

    import std.algorithm.sorting : assumeSorted;
    return s.assumeSorted!less;
}

/** Sort range `x` of length `n` using a networking sort.
 */
auto networkSortExactly(uint n, alias less = "a < b", Range)(Range r)
    if (isRandomAccessRange!Range)
in
{
    assert(r.length == n);
}
body
{
    x[].networkSortUpTo!n;
}

/** Sort static array `x` of length `n` using a networking sort.
 */
auto networkSortExactly(alias less = "a < b", T, size_t n)(ref T[n] x)
{
    x[].networkSortUpTo!n;
}

///
@safe pure nothrow @nogc unittest
{
    int[4] x = [2, 3, 0, 1];
    const int[4] y = [0, 1, 2, 3];
    x.networkSortExactly;
    assert(x[].equal(y[]));
}

/** Hybrid sort `r` using `networkSortUpTo` if length of `r` is less-than-or-equal to
    `networkSortMaxLength` and `std.algorithm.sorting.sort` otherwise.
 */
auto hybridSort(alias less = "a < b", Range)(Range r)
    if (isRandomAccessRange!Range)
{
    import std.algorithm.sorting : isSorted;
    foreach (uint n; iota!(2, networkSortMaxLength + 1))
    {
        static if (__traits(compiles, { r.networkSortUpTo!(n, less); }))
        {
            if (n == r.length)
            {
                auto s = r.networkSortUpTo!(n, less);
                assert(s.isSorted!less);
                return s;
            }
        }
    }
    import std.algorithm.sorting : sort;
    return sort!less(r);
}

///
@safe pure unittest
{
    import std.algorithm.sorting : isSorted;
    import std.algorithm.iteration : permutations;
    import std.range : iota;
    import std.random : randomShuffle, Random;

    Random random;

    alias T = uint;

    const maxFullPermutationTestLength = 8;
    const maxTriedShufflings = 10_000; // maximum number of shufflings to try

    import std.meta : AliasSeq;
    foreach (less; AliasSeq!("a < b", "a > b"))
    {
        foreach (const n; iota(0, networkSortMaxLength + 1))
        {
            if (n > maxFullPermutationTestLength) // if number of elements is too large
            {
                foreach (x; iota(0, maxTriedShufflings))
                {
                    import std.array : array;
                    auto y = iota(0, n).array;
                    y.randomShuffle(random);
                    y.hybridSort!less;
                    assert(y.isSorted!less);
                }
            }
            else
            {
                foreach (x; iota(0, n).permutations)
                {
                    import std.array : array;
                    auto y = x.array;
                    y.hybridSort!less;
                    assert(y.isSorted!less);
                }
            }
        }
    }
}

void measure(alias fun)(uint iterations=10_000) {
    import std.datetime;

    StopWatch sw = AutoStart.yes;
    for (uint i=0; i<iterations; i++)
        fun();
    sw.stop;
    stdout.writefln("  %s nsecs", sw.peek.to!("nsecs", real) / iterations);
}

void main() {
    import std.stdio;

    stdout.writeln("Normal Sort");
    measure!(() => [1, 9, 5, 4, 7, 8].sort);
    stdout.writeln("Optimized Sort");
    measure!(() => [1, 9, 5, 4, 7, 8].hybridSort);

}