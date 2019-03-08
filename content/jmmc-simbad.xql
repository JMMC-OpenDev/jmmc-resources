xquery version "3.0";

(:~
 : This modules contains functions to query Simbad through TAP.
 : 
 : It provides helpers to perform target resolutions (by name and by
 : coordinates) against Simbad's basic table.
 : 
 : TODO handle equinox of the coordinates / epoch
 : History:
 :    August 2017 : 
 :    - use votable/td for TAP queries (so we parse some tr/td result nodes) 
 :    - bump to V1.3 namespace
 :)
module namespace jmmc-simbad="http://exist.jmmc.fr/jmmc-resources/simbad";

declare namespace votable="http://www.ivoa.net/xml/VOTable/v1.3";
declare namespace http="http://expath.org/ns/http-client";

(: The Simbad TAP endpoint :)
declare variable $jmmc-simbad:TAP-SYNC := "http://simbad.u-strasbg.fr/simbad/sim-tap/sync";

(: Value of current votable namespace :)
declare variable $jmmc-simbad:vot-ns := namespace-uri(element votable:dummy {});

(:~
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second. 
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @return a VOTable with results for the query
 : @error service unavailable, bad response
 :)
declare %private function jmmc-simbad:tap-adql-query($uri as xs:string, $query as xs:string) as node() {
    let $uri := $uri || '?' || string-join((
        'REQUEST=doQuery',
        'LANG=ADQL',
        'FORMAT=votable/td', 
        'QUERY=' || encode-for-uri($query)), '&amp;')
    let $response        := http:send-request(<http:request method="GET" href="{$uri}"/>)
    let $response-status := $response[1]/@status 
    
    return if ($response-status != 200) then
        error(xs:QName('jmmc-simbad:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='||$query||')', $query) 
    else if (count($response[1]/http:body) != 1) then
        error(xs:QName('jmmc-simbad:TAP'), 'Bad content returned')
    else
        let $body := $response[2]
        return if ($body instance of node()) then $body else util:parse($body)
};

(:~
 : Return a target description from the VOTable row.
 : 
 : The description is made from the oid, ra and dec coordinates and the main
 : name.
 : 
 : @param $row a VOTable row
 : @return a target description as sequence 
 :)
declare %private function jmmc-simbad:target($row as element(votable:TR)) as element(target) {
    <target> {
        for $f at $i in $row/ancestor::votable:TABLE/votable:FIELD
        let $name  := $f/@name
        let $value := $row/votable:TD[position() = $i]/text()
        return element { $name } { $value }
    } </target>
};

(:~
 : Run a target resolution ADQL query against Simbad TAP service and return the rows of results.
 : 
 : @param $query the ADQL query to execute
 : @return target descriptions if resolution succeeds
 : @error not found, off coord hit
 :)
declare %private function jmmc-simbad:resolve($query as xs:string) as node()* {
    let $result   := jmmc-simbad:tap-adql-query($jmmc-simbad:TAP-SYNC, $query)
    let $resource := $result//votable:RESOURCE
    let $rows     := $resource//votable:TR
    let $test-ns  := if(empty($rows) and empty($result//votable:VOTABLE)) then error(xs:QName('jmmc-simbad:TAP'), 'Missing VOTABLE in response (namespace is '|| namespace-uri($result/*)||' and should be '|| $jmmc-simbad:vot-ns ||')') else ()
    (: return target details :)
    for $r in $rows return jmmc-simbad:target($r)
};

(:~
 : Escape a string for ADQL query.
 : 
 : @param $str the string to escape
 : @return the escaped string
 :)
declare %private function jmmc-simbad:escape($str as xs:string) as xs:string {
    (: FIXME more escapes? :)
    replace($str, "'", "''")
};

(:~
 : Try to identify a target from its name with Simbad.
 : 
 : @param $identifier the target name
 : @return a target identifier if target is found or a falsy if target is unknown
 :)
declare function jmmc-simbad:resolve-by-name($identifier as xs:string) as item()* {
    jmmc-simbad:resolve-by-name($identifier, (), ())
};

(:~
 : Try to identify a target from its fingerprint with Simbad.
 : 
 : @param $identifier the target name
 : @param $ra the target right ascension in degrees
 : @param $dec the target declination in degrees
 : @return a target identifier if target is found or a falsy if target is unknown
 :)
declare function jmmc-simbad:resolve-by-name($identifier as xs:string, $ra as xs:double?, $dec as xs:double?) as item()* {
    let $do-dist := ($ra and $dec)
    let $query := 
        "SELECT oid AS id, ra, dec, main_id AS name" || (if($do-dist) then ", DISTANCE(POINT('ICRS', ra, dec), POINT('ICRS', " || $ra || ", " || $dec || ")) AS dist " else " ") ||
        "FROM basic JOIN ident ON oidref=oid " ||
        "WHERE id = '" || jmmc-simbad:escape($identifier) || "' " ||
        (if($do-dist) then "ORDER BY dist" else "")
    (: TODO check distance of result from coords :)
    return jmmc-simbad:resolve($query)
};

(:~
 : Search for targets in the vicinity of given coords.
 : 
 : @param $ra a right ascension in degrees
 : @param $dec a declination in degrees
 : @param $radius the search radius in degrees
 : @return a sequence of identifiers for targets near the coords (sorted by distance)
 :)
declare function jmmc-simbad:resolve-by-coords($ra as xs:double, $dec as xs:double, $radius as xs:double) as item()* {
    jmmc-simbad:resolve(
        "SELECT oid AS id, ra, dec, main_id AS name, DISTANCE(POINT('ICRS', ra, dec), POINT('ICRS', " || $ra || ", " || $dec || ")) AS dist " ||
        "FROM basic " ||
        "WHERE CONTAINS(POINT('ICRS', ra, dec), CIRCLE('ICRS', " || $ra || ", " || $dec || ",  " || $radius || " )) = 1 " ||
        "ORDER BY dist")
};


(:~
 : Search for target names that match alias of given name.
 : @param $identifier the target name (case insensitive)
 : @param $max-items max number of returned elements (optional - default value 10)
 : 
 : @return a sequence of identifiers for targets which contains given identifier value (NAME part is removed)
 :)
declare function jmmc-simbad:search-names($identifier as xs:string, $max-items as xs:integer? ) as item()* {
    let $max-items := if($max-items) then $max-items else 10 
    let $query := "SELECT TOP " || $max-items || " id FROM ident AS id1 WHERE UPPER(id1.id) LIKE 'NAME %" || upper-case($identifier) || "%'"
    (: TODO avoid identifier in return :)
    let $result   := jmmc-simbad:tap-adql-query($jmmc-simbad:TAP-SYNC, $query)
    let $resource := $result//votable:RESOURCE
    let $rows     := $resource//votable:TR
    let $test-ns  := if(empty($rows) and empty($result//votable:VOTABLE)) then error(xs:QName('jmmc-simbad:TAP'), 'Missing VOTABLE in response (namespace is '|| namespace-uri($result/*)||' and should be '|| $jmmc-simbad:vot-ns ||')') else ()
    return for $r in $rows return substring(normalize-space($r),6) 
};
