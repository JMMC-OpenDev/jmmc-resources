xquery version "3.0";

(:~
 : Helper functions to convert star coordinates between different
 : formats and retrieve band limits
 : 
 : Based on the jmal package (fr.jmmc.jmal).
 :)

module namespace jmmc-astro="http://exist.jmmc.fr/jmmc-resources/astro";

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace alx="java:fr.jmmc.jmal.ALX";
declare namespace band="java:fr.jmmc.jmal.Band";

(:~
 : Convert a right ascension in degree to a sexagesimal time (hms).
 : 
 : @param $x right ascension in degrees
 : @return a string of three numbers for hour, minutes and seconds.
 :)
declare
    %test:arg("x", 24.429284)
    %test:assertEquals("01:37:43.028")
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
    %test:assertEquals("+57:14:12.300")
function jmmc-astro:to-dms($x as xs:double) as xs:string{
    alx:to-d-m-s($x)
};

(:~
 : Convert a sexagesimal value for declination (dms) to degrees.
 : 
 : @param $s a string of three values for degrees minutes and seconds,
 :           space- or colon-separated
 : @return the declination in degrees 
 : @error failed to parse declination
 :)
declare
    %test:arg("s", "57:14:12.3")
    %test:assertEquals(57.23675)
    %test:arg("s", "bad dms")
    %test:assertError("jmmc-astro:format")
function jmmc-astro:from-dms($s as xs:string) as xs:double {
    let $dec := alx:parse-d-e-c($s)
    return if (string($dec) = 'NaN') then
        error(xs:QName('jmmc-astro:format'), 'Failed to parse declination "' || $s || '"')
    else
        $dec
};

(:~
 : Convert a sexagesimal value for a right ascension (hms) to degrees.
 : 
 : @param $s a string of three values for hours minutes and seconds,
 :           space- or colon-separated
 : @return the right ascension in degrees
 : @error failed to parse right ascension
 :)
declare
    %test:arg("s", "18 32 49.9577")
    %test:assertEquals(2.7820815708333333e2)
    %test:arg("s", "bad hms")
    %test:assertError("jmmc-astro:format")
function jmmc-astro:from-hms($s as xs:string) as xs:double {
    let $ra := alx:parse-h-m-s($s)
    return if (string($ra) = 'NaN') then
        error(xs:QName('jmmc-astro:format'), 'Failed to parse right ascension "' || $s || '"')
    else
        $ra
};

(:~ stores bounds of visible, near-ir and mid-ir wavelength divisions.
 :)
declare %private variable $jmmc-astro:wavelength-divisions := map {
                                "Visible":( 0.3, 1 ),
                                "Near infrared":( 1,   5 ),
                                "Mid infrared" :( 5,   18.6 )
};

(:~
 : Return a list of optical wavelength division names.
 : 
 : @return a sequence of strings with division ids
 :)
declare function jmmc-astro:wavelength-division-names() as item()* {
 for $d in map:keys($jmmc-astro:wavelength-divisions)
   let $r:=$jmmc-astro:wavelength-divisions($d)
     order by $r[1]
     return $d 
};

(:~
 : Return a list of all band names.
 : 
 : @return a sequence of strings with band ids
 :)
declare function jmmc-astro:band-names() as item()* {
    for $b in band:values() return band:get-name($b)
};

(:~
 : Return the lower and upper wavelengths of the given band or division.
 : 
 : @param $band-name the name of the band or division
 : @return a sequence of two numbers for lower and upper wavelengths in microns
 : @error unknown band
 :)
declare
    %test:arg("band-name", "U")
    %test:assertEquals(0.30100000000000005, 0.367)
function jmmc-astro:wavelength-range($band-name as xs:string) as item()* {
    let $band := band:values()[band:getName(.) = $band-name]
    return 
        if (empty($band)) then
            let $div-range := $jmmc-astro:wavelength-divisions($band-name)
            return
                if( empty($div-range) ) then
                    error(xs:QName('jmmc-astro'), 'Unknown band: ' || $band-name)
                else
                    $div-range
        else
            let $lambda    := band:get-lambda($band)
            let $half-bandwidth := band:get-band-width($band) div 2
            return ( $lambda - $half-bandwidth, $lambda + $half-bandwidth)
};


