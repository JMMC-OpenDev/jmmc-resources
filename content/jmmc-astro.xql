xquery version "3.0";

(:~
 : Helper functions to convert star coordinates between different formats.
 : 
 : Based on the jmal package (fr.jmmc.jmal). Require the jmal JAR file in
 : the content/ directory.
 : 
 : Todo: - fix the bad format issue with to-dms, to-hms
 :       - add note on locale dependency (numeric delimiter in seconds)
 :)

module namespace jmmc-astro="http://exist.jmmc.fr/jmmc-resources/astro";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace alx="java:fr.jmmc.jmal.ALX";

(:~
 : Convert a right ascension in degree to a sexagesimal time (hms).
 : 
 : @param $x right ascension in degrees
 : @return a string of three numbers for hour, minutes and seconds.
 :)
declare
    %test:arg("x", 24.429284)
    %test:assertEquals("1:37:43.028")
function jmmc-astro:to-hms($x as xs:double) as xs:string {
    alx:to-h-m-s($x)
};

(:~
 : Convert a declination in degree to a sexagesimal angle (dms).
 : 
 : @param $x declination in degrees
 : @param a sequence of numbers for angle, minutes and seconds.
 :)
declare
    %test:arg("x", 57.23675)
    %test:assertEquals("57:14:12.3")
function jmmc-astro:to-dms($x as xs:double) as xs:string{
    alx:to-d-m-s($x)
};

(:~
 : Convert a sexagesimal value for declination (dms) to degrees.
 : 
 : @param $s a string of three values for degrees minutes and seconds,
 :           space- or colon-separated
 : @return the declination in degrees 
 : @todo check return value: if NaN, format error
 :)
declare
    %test:arg("s", "57:14:12.3")
    %test:assertEquals(57.23675)
function jmmc-astro:from-dms($s as xs:string) as xs:double {
    alx:parse-d-e-c($s)
};

(:~
 : Convert a sexagesimal value for a right ascension (hms) to degrees.
 : 
 : @param $s a string of three values for hours minutes and seconds,
 :           space- or colon-separated
 : @return the right ascension in degrees
 : @todo check return value: if NaN, format error
 :)
declare
    %test:arg("s", "1 37 42.0")
    %test:assertEquals(24.425)
function jmmc-astro:from-hms($s as xs:string) as xs:double {
    alx:parse-r-a($s)
};
