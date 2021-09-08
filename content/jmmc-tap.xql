xquery version "3.1";

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
 
 @param $uri SYNC tap endpoint URI
 :)
declare %private function jmmc-tap:_tap-adql-query($uri as xs:string, $query as xs:string, $maxrec as xs:integer?, $format as xs:string?) {
    let $uri := $uri || '?' || string-join((
        'REQUEST=doQuery',
        'LANG=ADQL',
        'FORMAT='||( if( $format) then $format else 'votable/td' ) , (: votable/td replaces in vollt old votable of taplib :) 
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
        return 
            try {
                if($format="application/json") then
                    parse-json(util:base64-decode($body))
                else 
                    if ($body instance of node()) then 
                        $body 
                    else
                        fn:parse-xml($body)    
            } catch * {
                $body
            }
};


(:~ 
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second. 
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @return a VOTable with results for the query (result is cached: see tap-clear-cache() ) or other requested format
 : @error service unavailable, bad response
 : 
 :)
declare function jmmc-tap:tap-adql-query($uri as xs:string, $query as xs:string, $maxrec as xs:integer?) {
    jmmc-tap:tap-adql-query($uri, $query, $maxrec, ())
};

(:~ 
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second. 
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @param $format optional format / votable by default
 : @return a VOTable with results for the query (result is cached: see tap-clear-cache() )  or other requested format
 : @error service unavailable, bad response
 : 
 :)
declare function jmmc-tap:tap-adql-query($uri as xs:string, $query as xs:string, $maxrec as xs:integer?, $format as xs:string?)  {
let $cache-name := $jmmc-tap:cache-prefix||$uri
let $cache-key := $query||$maxrec||$format
let $cached := cache:get($cache-name, $cache-key) 
    return 
        if(exists($cached)) then $cached
        else 
            let $res := jmmc-tap:_tap-adql-query($uri, $query, $maxrec, $format)
            let $store := cache:put($cache-name, $cache-key, $res)
            return $res
};

declare function jmmc-tap:clear-cache($uri as xs:string){
    let $cache-name := $jmmc-tap:cache-prefix||$uri
    return cache:clear($cache-name)   
};

declare function jmmc-tap:tap-clear-cache() {
    let $to-clean :=  cache:names()[starts-with(., $jmmc-tap:cache-prefix)]
    for $cache-name in $to-clean return cache:clear($cache-name)
};

declare function jmmc-tap:get-db-colname( $vot-field ) 
{
    let $field-name := ( $vot-field/@name, $vot-field )[1] (: search in votable field or use str param :)
    (: TODO  mimic better stilts conversion see : https://github.com/Starlink/starjava/blob/master/table/src/main/uk/ac/starlink/table/jdbc/JDBCFormatter.java :)
    let $name := lower-case($field-name) ! translate(., "()-", "___") 
    return if($name="publication") then $name||"_" else $name
};

declare function jmmc-tap:get-db-datatype($vot-field)
{
    
(:    TODO: :)
(:        - add support for V1_1 https://www.ivoa.net/documents/TAP/20180830/PR-TAP-1.1-20180830.html#tth_sEc4.3:)
(:        - support all datatype : boolean bit unsignedByte short int long char unicodeChar float double floatComplex doubleComplex:)
(:        - and votable types https://www.ivoa.net/xml/VOTable/VOTable-1.4.xsd:)
(:        - use timestamp when MJD declared in votable ?:)
(: :)
(: see also https://www.w3.org/2001/sw/rdb2rdf/wiki/Mapping_SQL_datatypes_to_XML_Schema_datatypes :)
    let $datatype := $vot-field/@datatype
    return 
        switch ($datatype)
            case "char" case "unicodeChar" return "VARCHAR"
            case "double" return "DOUBLE PRECISION"
            case "long" case "int" case "short" return "INTEGER"
            default return $datatype
};

(:~ 
 : Transform your votable to an SQL statement template so you can create a table in your rdbms.
 :
 : Warning: tested on postgresql only
 :
 : @param $table-name optional parameter that overwrite the VOTABLE/@name attribute
 : @param $primary-key-name optional column name to declare as primary key
 : @return table creation SQL statement
 : 
 :)
declare
    %rest:POST("{$vot}")
    %rest:path("/votable2sql")    
    %rest:query-param("table-name", "{$table-name}")
    %rest:query-param("primary-key-name", "{$primary-key-name}")    
    function jmmc-tap:votable2sql($vot as document-node()?, $table-name, $primary-key-name) 
{ 
    (: TODO:
        - return a comment atht highlight naming changes operated by get-db-name  if any
        - check for all version of ucds ... to get at least one ?
        - assume that some column are 
          - using timestamp when MJD declared in votable ?
        - indexation  
        - more column constraints ?
        where column_constraint is:
            [ CONSTRAINT constraint_name ]
            { NOT NULL |
              NULL |
              CHECK ( expression ) |
              DEFAULT default_expr |
              UNIQUE index_parameters |
              PRIMARY KEY index_parameters |
              REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ]
                [ ON DELETE action ] [ ON UPDATE action ] }
            [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]
          
    :)
    let $table-name := if($table-name) then $table-name else $vot//*:TABLE/@name
    let $table-name := jmmc-tap:get-db-colname($table-name) (: normalize table name like a colname :)
    
    let $comments:= ("")
    let $comments := ($comments, if(exists($table-name))  then "Using "||$table-name|| " as table name" else "Missing value for table-name , please add it to VOTABEL@name or as table-name query param")
    let $comments := ($comments, if(exists($primary-key-name))  then "Using "||$primary-key-name|| " key as primary key" else "No primary key given to primary-key-name as query param")
    let $comments := ($comments, "","No content extracted, please use the catalog API to injest dat or ask jmmc-tech-group for such enhancement")
    let $sql-comments := string-join($comments , "&#10;-- ")
    
    let $cols-create := 
        for $f in $vot//*:FIELD
            let $colname := jmmc-tap:get-db-colname($f)
            let $datatype := jmmc-tap:get-db-datatype($f)
            let $col-constraint := if($primary-key-name = $colname) then "PRIMARY KEY" else ()
            return 
                ("  ", $colname, "          ", $datatype, $col-constraint ) => string-join(" ")
    
    let $create := ( 'CREATE TABLE ' || $table-name
                    , '('
                    , string-join($cols-create, ", &#10;")
                    , ')'
                    ,""
                    )
    let $sql-create := string-join($create, "&#10;")
    
    let $sql := string-join(($sql-comments, "", $sql-create), "&#10;")
        
    return $sql
};

declare
    %rest:POST("{$vot}")
    %rest:path("/votable2tapschema")    
    %rest:query-param("table-name", "{$table-name}")
    %rest:query-param("primary-key-name", "{$primary-key-name}")    
    function jmmc-tap:votable2schema($vot as document-node(), $table-name, $table-desc, $primary-key-name) 
{ 
    (: TODO:
        - return a comment atht highlight naming changes operated by get-db-name  if any
        - handle table-desc if any given or use votable's one
        - check for all version of ucds ... to get at least one ?
    :)
    
    let $table-name := if($table-name) then $table-name else $vot//*:TABLE/@name
    let $table-name := jmmc-tap:get-db-colname($table-name) (: normalize table name like a colname :)
    
    let $i := "INSERT INTO &quot;TAP_SCHEMA&quot;.&quot;tables&quot; VALUES ('public', '"|| $table-name ||"', 'table', '"|| $table-name ||"', NULL);"
    
    let $insert := 'INSERT INTO "TAP_SCHEMA"."columns" ("table_name", "column_name", "description", "unit", "ucd", "utype", "datatype", "size", "principal", "indexed", "std") VALUES '
    let $values := 
        for $f in $vot//*:FIELD
            let $colname := jmmc-tap:get-db-colname($f)
            let $desc := $f/*:DESCRIPTION||""
            let $unit := $f/@unit||""
            let $ucd := $f/@ucd||"" 
            let $utype := $f/@utype||""
            let $datatype := tokenize(jmmc-tap:get-db-datatype($f)," ")[1]
            let $size := -1
            
            let $v := ($table-name, $colname, $desc, $unit, $ucd, $utype, $datatype, $size, 0,0,0) ! concat("&apos;", ., "&apos;")
        return 
            "(" || string-join($v, ", ") || ")"
        
    return string-join(($i, $insert, string-join($values, ",&#10;"),""), "&#10;")
};