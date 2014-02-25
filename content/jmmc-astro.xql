xquery version "3.0";

(:~
 : Helper functions to convert star coordinates between different formats.
 :)

module namespace jmmc-astro="http://exist.jmmc.fr/jmmc-resources/astro";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

(:~
 : A helper to convert a decimal value to a sexagesimal value
 : (hms or dms).
 : 
 : @param $x a decimal value
 : @return a sequence of three numbers
 :)
declare %private function jmmc-astro:to-xms($x as xs:double) as item()* {
    let $modf := function ($x as xs:double) { ( floor($x), $x - floor($x) ) }

    let $sign  := if ($x < 0) then -1 else 1
    let $x-xf  := $modf(abs($x))
    let $m-mf  := $modf($x-xf[2] * 60)
    let $s     := $m-mf[2] * 60
    return ( $sign * $x-xf[1], $m-mf[1], $s)
};

(:~
 : Convert a right ascension in degree to a sexagesimal time (hms).
 : 
 : @param $x right ascension in degrees
 : @return a sequence of three numbers for hour, minutes and seconds.
 :)
declare
    %test:arg("x", 24.429284)
    %test:assertEquals(1, 37, 43.02815999999851)
function jmmc-astro:to-hms($x as xs:double) as item()* {
    let $hours := (($x + 360) mod 360) * 24 div 360
    return jmmc-astro:to-xms($hours)
};

(:~
 : Convert a declination in degree to a sexagesimal angle (dms).
 : 
 : @param $x declination in degrees
 : @param a sequence of numbers for angle, minutes and seconds.
 :)
declare
    %test:arg("x", 57.23675)
    %test:assertEquals(57, 14, 12.300000000002456)
function jmmc-astro:to-dms($x as xs:double) as item()* {
    let $degrees := $x mod 360
    return jmmc-astro:to-xms($degrees)
};

(:~
 : Format a sexagesimal value to a string.
 : 
 : The three number of the sexagesimal value are joined by space,
 : the second number is truncated to two decimal digits.
 : 
 : @param $hms a sequence of three numbers
 : @param a string of three whitespace separated numbers
 :)
declare
    %test:arg("hms", 1, 37, 42.84548)
    %test:assertEquals("1 37 42.85")
function jmmc-astro:format-sexagesimal($hms as xs:double+) as xs:string {
    $hms[1] || " " || $hms[2] || " " || format-number($hms[3], ".00")
};

(:~
 : A helper to convert a sexagesimal value to a decimal value.
 : 
 : @param $s a sequence of three numbers
 : @return the decimal value of $s
 :)
declare %private function jmmc-astro:from-xms($s as xs:double+) as xs:double{
    let $sign := if ($s[1] < 0) then -1 else 1
    return $s[1] + $sign * $s[2] div 60 + $sign * $s[3] div 3600
};

(:~
 : Convert a sexagesimal value for declination (dms) to degrees.
 : 
 : @param $s a sequence of three values for degrees minutes and seconds
 : @return the declination in degrees 
 :)
declare
    %test:arg("s", 57, 14, 12.3)
    %test:assertEquals(57.23675)
function jmmc-astro:from-dms($s as xs:double+) as xs:double {
    jmmc-astro:from-xms($s)
};

(:~
 : Convert a sexagesimal value for a right ascension (hms) to degrees.
 : 
 : @param $s sequence of three values for hours minutes and seconds
 : @return the right ascension in degrees
 :)
declare
    %test:arg("s", 1, 37, 42.0)
    %test:assertEquals(24.425)
function jmmc-astro:from-hms($s as xs:double+) as xs:double {
    jmmc-astro:from-xms($s) * 360 div 24
};

(:~
 : Parse a sexagesimal triplet (hours or degrees, minutes and seconds).
 : 
 : If the string has more or not enough parts and if the numbers
 : have a bad format, an error is generated.
 : 
 : @param $s a space separated string of 3 numbers
 : @return a sequence of 3 doubles
 : @error Failed to parse sexagesimal coordinates.
 :)
declare 
    %test:args('1 37')
    %test:assertError("jmmc-astro:SyntaxError")
    %test:args('1 3X 42.84548')
    %test:assertError("jmmc-astro:SyntaxError")
    %test:args('1 37 42.84548')
    %test:assertEquals("1", "37", "42.84548")
function jmmc-astro:parse-sexagesimal($s as xs:string) as item()* {
    let $tokens := tokenize($s, '\s')
    return 
        (: require exactly 3 parts: no more and no missing/incomplete coord :)
        if (count($tokens) != 3) then
            error(xs:QName('jmmc-astro:SyntaxError'), 'Failed to parse sexagesimal coordinates.')
        else
            try {
                (: cast all string to numbers :)
                for $x in $tokens return xs:double($x)
            } catch * {
                (: catch format error in numbers :)
                error(xs:QName('jmmc-astro:SyntaxError'), 'Failed to parse sexagesimal coordinates.')
            }
};
