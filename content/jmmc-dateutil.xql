xquery version "3.0";

(:~
 : Utility functions for dates ( RFC822/RSS, MJD , elapsedTime)
 : Import module 
 : import module namespace jmmc-dateutil="http://exist.jmmc.fr/jmmc-resources/dateutil" at "/db/apps/jmmc-resources/content/jmmc-dateutil.xql";
 : or import last version of updated library 
 : 
 : TODO: re-implement following conversion formulae  ( see https://fr.wikipedia.org/wiki/Jour_julien#cite_note-Source_Meeus-5 )
 : GM trusts xquery date handling LB not ;)
 : 
 :)
module namespace jmmc-dateutil="http://exist.jmmc.fr/jmmc-resources/dateutil";

(:~
 : Return day abbreviation.
 : 
 : @param $dateTime date to analyse
 : @return Sun, Mon, Tue, Wed, Thu, Fri, Sat according given date.
 :)
declare function jmmc-dateutil:day-abbreviation($dateTime as xs:dateTime)
as xs:string
{
    let $y := fn:year-from-dateTime($dateTime) - 1901
    let $d := fn:day-from-dateTime($dateTime)
    return
        ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat')[xs:integer((($y + fn:floor($y div 4) - fn:floor($y div 100) +
                                                                         fn:floor($y div 400) + $d) mod 7) + 1)]
};

(:~
 :  Return Month abreviation
 : 
 :  @param $dateTime given date
 :  @return month abreviation of given date
 :)
declare function jmmc-dateutil:month-abbreviation($dateTime as xs:dateTime)
as xs:string
{
    ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec
        ')[fn:month-from-dateTime($dateTime)]
};

declare function jmmc-dateutil:format-timezone($dateTime as xs:dateTime)
as xs:string
{
    let $timezoneOffset := concat(fn:timezone-from-dateTime($dateTime), "")
    let $plusMinus := if (fn:substring-before($timezoneOffset, 'PT') = '-') then "-" else "+"
    let $tzVal := xs:integer(substring-before(substring-after($timezoneOffset, 'PT'), 'H')) * 100
    let $tzHour := if ($tzVal idiv 100 = 0) then "00" else xs:string($tzVal idiv 100)
    let $tzMin := if ($tzVal mod 100 = 0) then "00" else "30"
    let $tzStr := (if ($tzHour = "00" and $tzMin = "00") then "GMT" else fn:concat($plusMinus, $tzHour, $tzMin) )
    return $tzStr
};

declare function jmmc-dateutil:format-number($number as xs:integer)
as xs:string
{
    if ($number <= 9) then fn:concat("0", $number) else xs:string($number)
};

(:~
 :  Return iso8601 date to RFC822 (used by RSS format)
 : 
 :  @param $dateTime given date
 :  @return rfc822 date
 :)
declare function jmmc-dateutil:ISO8601toRFC822($dateTime as xs:dateTime)
as xs:string
{
    (: following start is not compliant because it can fail... :  jmmc-dateutil:day-abbreviation($dateTime), ', ', :)
        fn:concat(jmmc-dateutil:format-number(fn:day-from-dateTime($dateTime)), ' ',
                  jmmc-dateutil:month-abbreviation($dateTime), ' ', fn:year-from-dateTime($dateTime), ' ',
                  jmmc-dateutil:format-number(fn:hours-from-dateTime($dateTime)), ':',
                  jmmc-dateutil:format-number(fn:minutes-from-dateTime($dateTime)), ':',
                  jmmc-dateutil:format-number(fn:ceiling(fn:seconds-from-dateTime($dateTime))), ' ', '+0200')
};


(:~
 : Convert a mjd date to iso8601
 : 
 : @param $mjd Modified Julian Day to convert
 : @return the associated datetime
 :)
declare function jmmc-dateutil:MJDtoISO8601($mjd as xs:double)
as xs:dateTime
{
    (: http://tycho.usno.navy.mil/mjd.html
        $JD0  := xs:dateTime("-4712-01-01T12:00:00")    
        $MJD0 := $JD0 + xs:dayTimeDuration('P1D')* 2400000.5 
              := 1858-12-25T00:00:00 as computed by exist-db
              but should be 1858-11-17T00:00:00       
    :)
    xs:dateTime("1858-11-17T00:00:00") + $mjd * xs:dayTimeDuration('P1D')
};

(:~
 : Convert an iso8601 date to mjd 
 : 
 : @param $dateTime datetime to convert
 : @return the associated mjd
 :)
declare function jmmc-dateutil:ISO8601toMJD($dateTime as xs:dateTime)
as xs:double
{
    ($dateTime - xs:dateTime("1858-11-17T00:00:00")) div xs:dayTimeDuration('P1D')    
};


(:~
 : Convert a Julian Day to iso8601
 : 
 : @param $jd Julian Day to convert
 : @return the associated datetime
 :)
declare function jmmc-dateutil:JDtoISO8601($jd as xs:double)
as xs:dateTime
{
    (: http://aa.usno.navy.mil/cgi-bin/aa_jdconv.pl?form=2&jd=0
        $JD0  := xs:dateTime("-4713-01-01T12:00:00")    
            but should be -4713-11-24T12:00:00      
    :)
    xs:dateTime("-4713-11-24T12:00:00") + $jd * xs:dayTimeDuration('P1D')
};


(:~
 : Convert an iso8601 to Julian Day
 : 
 : @param $dateTime datetime to convert
 : @return the associated jd
 :)
declare function jmmc-dateutil:ISO8601toJD($dateTime as xs:dateTime)
as xs:double
{
    ($dateTime - xs:dateTime("-4714-11-24T12:00:00")) div xs:dayTimeDuration('P1D')    
};

(:~
 : Convert an UT date to iso8601
 : 
 : @param $ut UT date to convert [s]
 : @param $epoch reference epoch of J2000 if empty
 : @return the associated datetime
 :)
declare function jmmc-dateutil:UTtoISO8601($ut as xs:double, $epoch as xs:double?)
as xs:dateTime
{
    let $epoch := if(exists($epoch)) then $epoch else xs:dateTime("2000-01-01T00:00:00")
    return
      $ut * xs:dayTimeDuration('PT1S') + $epoch
};


(:~
 : Convert an iso8601 to UT date
 : 
 : @param $dateTime datetime to convert
 : @param $epoch reference epoch of J2000 if empty
 : @return the associated ut [s]
 :)
declare function jmmc-dateutil:ISO8601toUT($dateTime as xs:dateTime, $epoch as xs:double?)
as xs:double
{
    let $epoch := if(exists($epoch)) then $epoch else xs:dateTime("2000-01-01T00:00:00")
    return
      ( $dateTime - $epoch ) div xs:dayTimeDuration('PT1S')
};

(:~
 : Convert an UT date to MJD
 : 
 : @param $dateTime datetime to convert
 : @param $epoch reference epoch of J2000 if empty
 : @return the associated ut [s]
 :)
declare function jmmc-dateutil:UTtoMJD($ut as xs:double, $epoch as xs:double?)
as xs:double
{
    let $epoch := if(exists($epoch)) then $epoch else xs:dateTime("2000-01-01T00:00:00")
    return
         ( $ut * xs:dayTimeDuration('PT1S') + $epoch - xs:dateTime("1858-11-17T00:00:00") ) div xs:dayTimeDuration('P1D')
};



(:~
 : Compute abreviation of elasped time.
 : TODO complete cases
 : e.g.: 32 sec. ago
 : 2 h. ago
 : 1 day ago
 : 3 months ago
 : 4 years ago
 :  :)
declare function jmmc-dateutil:durationInPast($dateTime as xs:dateTime)
{
    let $duration := current-dateTime() - $dateTime
    let $nbMonths := months-from-duration($duration)
    let $nbDays := days-from-duration($duration)
    let $durationInPast :=
        if ($nbMonths > 0) then
            "" || $nbMonths || "t"
        else
            "" || $nbMonths || " todo " || $nbDays
    return
        <a href="#" title="{ $dateTime }">{ $durationInPast }</a>
};


(:~
 : Compute abreviation of elasped time.
 :)
declare function jmmc-dateutil:duration($from as xs:time)
{
    jmmc-dateutil:duration($from, util:system-time() , ())
};

(:~
 : Compute abreviation of elasped time.
 :)
declare function jmmc-dateutil:duration($from as xs:time, $label)
{
    jmmc-dateutil:duration($from, util:system-time() , $label)
};


(:~
 : Compute abreviation of elasped time.
 :)
declare function jmmc-dateutil:duration($from as xs:time, $to as xs:time, $label)
{
    let $duration := $to - $from
    return
        <a href="#" title="from { $from } to {$to} : {$duration}">{if(exists($label)) then ($label, "&#160;") else ()} { seconds-from-duration($duration) }s</a>
};


