xquery version "3.0";

(:~
 : This modules contains functions to query tap services through TAP.
 : 
 : - check the proper xml namespace bump to V1.3 namespace
 :)
module namespace jmmc-tap="http://exist.jmmc.fr/jmmc-resources/tap";

declare namespace votable="http://www.ivoa.net/xml/VOTable/v1.3";
declare namespace http="http://expath.org/ns/http-client";

(: Some TAP endpoints :)
declare variable $jmmc-tap:SIMBAD-SYNC := "http://tap.u-strasbg.fr/tap/sim-tap/sync";
declare variable $jmmc-tap:OIDB-SYNC := "http://oidb.jmmc.fr/tap/sync";

(: Value of current votable namespace :)
declare variable $jmmc-tap:vot-ns := namespace-uri(element votable:dummy {});

declare variable $jmmc-tap:cache-prefix := "_jmmc-tap-cache-";

(:~
 
 :)
declare %private function jmmc-tap:_tap-adql-query($uri as xs:string, $query as xs:string, $maxrec as xs:integer?) as node() {
    let $uri := $uri || '?' || string-join((
        'REQUEST=doQuery',
        'LANG=ADQL',
        'FORMAT=votable/td', 
        'MAXREC=' || ( if ($maxrec) then  $maxrec else '-1' ),
        'QUERY=' || encode-for-uri($query)), '&amp;')
    let $response        := http:send-request(<http:request method="GET" href="{$uri}"/>)
    let $response-status := $response[1]/@status 
    
    return if ($response-status != 200) then
        error(xs:QName('jmmc-tap:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='||$query||')', $query) 
    else if (count($response[1]/http:body) != 1) then
        error(xs:QName('jmmc-tap:TAP'), 'Bad content returned')
    else
        let $body := $response[2]
        return if ($body instance of node()) then $body else fn:parse-xml($body)
};


(: 
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second. 
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @return a VOTable with results for the query (result is cached: see tap-clear-cache() )
 : @error service unavailable, bad response
 : 
 :)
declare function jmmc-tap:tap-adql-query($uri as xs:string, $query as xs:string, $maxrec as xs:integer?) as node() {
let $cached := cache:get($jmmc-tap:cache-prefix||$uri, $query) 
    return 
        if($cached) then $cached
        else 
            let $res := jmmc-tap:_tap-adql-query($uri, $query, $maxrec)
            let $store := cache:put($jmmc-tap:cache-prefix||$uri, $query, $res)
            return $res
};

declare function jmmc-tap:tap-clear-cache() {
    let $to-clean :=  cache:names()[starts-with(., $jmmc-tap:cache-prefix)]
    for $cache-name in $to-clean return cache:clear($cache-name)
};

declare function jmmc-tap:get-db-colname( $vot-field ) 
{
    let $field-name := $vot-field/@name
    (: TODO  mimic better stilts conversion see : https://github.com/Starlink/starjava/blob/master/table/src/main/uk/ac/starlink/table/jdbc/JDBCFormatter.java :)
    let $name := lower-case($field-name) ! translate(., "()-", "___") 
    return if($name="publication") then $name||"_" else $name
};

declare function jmmc-tap:get-db-datatype($vot-field)
{
    let $datatype := $vot-field/@datatype
    return 
        switch ($datatype)
            case "char" case "unicodeChar"return "VARCHAR"
            default return $datatype
};

declare function jmmc-tap:votable2schema($vot, $table-name as xs:string, $table-desc as xs:string) 
{ 
    (: TODO:
        - check for all version of ucds ... to get at least one ?
        - assume that some column are 
        - add support for V1_1 https://www.ivoa.net/documents/TAP/20180830/PR-TAP-1.1-20180830.html#tth_sEc4.3
        - support all datatype : boolean bit unsignedByte short int long char unicodeChar float double floatComplex doubleComplex
          - using timestamp when MJD declared in votable ?
        
    :)
    let $i := "INSERT INTO &quot;TAP_SCHEMA&quot;.&quot;tables&quot; VALUES ('public', 'spica', 'table', 'SPICA-DB test', NULL);"
    
    let $insert := 'INSERT INTO "TAP_SCHEMA"."columns" ("table_name", "column_name", "description", "unit", "ucd", "utype", "datatype", "size", "principal", "indexed", "std") VALUES '
    let $values := 
        for $f in $vot//*:FIELD
            let $colname := jmmc-tap:get-db-colname($f)
            let $desc := $f/*:DESCRIPTION||""
            let $unit := $f/@unit||""
            let $ucd := $f/@ucd||"" 
            let $utype := $f/@utype||""
            let $datatype := jmmc-tap:get-db-datatype($f)
            let $size := -1
            
            let $v := ($table-name, $colname, $desc, $unit, $ucd, $utype, $datatype, $size, 0,0,0) ! concat("&apos;", ., "&apos;")
        return 
            "(" || string-join($v, ", ") || ")"
        
    return string-join(($i, $insert, string-join($values, ",&#10;")), "&#10;")
};
