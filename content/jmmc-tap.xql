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
declare variable $jmmc-tap:SIMBAD-SYNC := "http://simbad.u-strasbg.fr/simbad/sim-tap/sync";
declare variable $jmmc-tap:OIDB-SYNC := "http://oidb.jmmc.fr/tap/sync";

(: Value of current votable namespace :)
declare variable $jmmc-tap:vot-ns := namespace-uri(element votable:dummy {});

declare variable $jmmc-tap:cache-prefix := "_jmmc-tap-cache-";
declare variable $jmmc-tap:cache-size := 1024; (: extend default value of 128 :)


(:~
 : Convert given html table to VOTable v1.3
 : - names of FIELDS are retrieved from th values with my_ prefix
 : - datatypes of FIELDS are double or string (guess is done from first row).
 : @param $table input table
 : @param $name name of created TABLE (that can be use for later query with tap-upload)
 :)
declare function jmmc-tap:table2votable($table, $name){
    <VOTABLE xmlns="http://www.ivoa.net/xml/VOTable/v1.3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.4" xsi:schemaLocation="http://www.ivoa.net/xml/VOTable/v1.3 http://www.ivoa.net/xml/VOTable/v1.3">
        <RESOURCE type="input">
            <TABLE name="{$name}">
                {
                    let $first-td-to-guess-types := ($table//*:tr[*:td])[1]/*:td
                    for $col at $pos in $table//*:th
                        let $type := try{ let $a := xs:double($first-td-to-guess-types[$pos]) return "double"} catch * {"char"}
                        let $arraysize := if($type="char") then "*" else "1"
                        return <FIELD datatype="{$type}" arraysize="{$arraysize}" name="my_{$col}"/>
                }
                <DATA>
                    <TABLEDATA>
                        { for $tr in $table//*:tr[*:td] return <TR>{for $td in $tr/*:td return <TD>{data($td)}</TD>}</TR> }
                    </TABLEDATA>
                </DATA>
            </TABLE>
        </RESOURCE>
    </VOTABLE>
};



declare function jmmc-tap:tap-adql-query-uri($uri as xs:string, $query as xs:string, $maxrec as xs:integer?, $format as xs:string?) {
    let $uri := $uri || '?' || string-join((
        'REQUEST=doQuery',
        'LANG=ADQL',
        'FORMAT='||( if( $format) then $format else 'votable/td' ) , (: votable/td replaces in vollt old votable of taplib :)
        'MAXREC=' || ( if ($maxrec) then  $maxrec else '-1' ),
        'QUERY=' || encode-for-uri(normalize-space($query))), '&amp;')

    return $uri
};


(:~
 : Perform a sync TAP request with an optional votable to upload.
 : table name (//TABLE@name) must be used in query using tap_upload. prefix
 : @param $uri SYNC tap endpoint URI
 :)
declare %private function jmmc-tap:_tap-adql-query($uri as xs:string, $query as xs:string, $votable as node()?, $maxrec as xs:integer?, $format as xs:string?, $votable-name as xs:string?) {

    let $params := map{
        'REQUEST':'doQuery',
        'LANG':'ADQL',
        'FORMAT': if( $format) then $format else 'votable/td'  , (: votable/td replaces in vollt old votable of taplib :)
        'MAXREC': if ($maxrec) then  $maxrec else -1 ,
        'QUERY': normalize-space($query)
    }

    let $response := try {
        jmmc-tap:_send-request($uri, $params, $votable, $votable-name)
    } catch * {
        util:wait(200)
(:        ,jmmc-tap:_send-request($uri, $params, $votable):)
    }
    let $response-status := $response[1]/@status

    return if ($response-status = (200,400,500)) then (: some implementations do return a 400 or 500 error code but a votable in case of error :)
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
                error(xs:QName('jmmc-tap:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='||$query|| ', body='||$body|| ')', $response)
            }
    else if (count($response[1]/http:body) != 1) then
        error(xs:QName('jmmc-tap:TAP'), 'Bad content returned')
    else
        error(xs:QName('jmmc-tap:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='||$query||')', $response)

};

(:~
 : Format query and send a get request if votable is not present else do a post request.
 :
 :)
declare %private function jmmc-tap:_send-request($uri, $params, $votable, $votable-name){
    if (exists($votable)) then
        let $table-name := data($votable//*:TABLE/@name)
        let $params := map:merge(( $params, map{'UPLOAD': ($votable-name,$table-name)[1]||',param:table1'} ))
        return
            http:send-request(<http:request method="POST" href="{$uri}">
                <http:multipart media-type="multipart/form-data" boundary="----------JMMCTAPXQL">
                    <http:header name='Content-Disposition' value='form-data; name="table1"; filename="table1.vot"'/>
                    <http:body media-type='application/xml'>{$votable}</http:body>
                    {
                        map:for-each($params, function($key, $value) {
                            <http:header name='Content-Disposition' value='form-data; name="{$key}"'/>
                            ,<http:body media-type="text/plain">{$value}</http:body>
                        })
                    }
                </http:multipart>
            </http:request>)
    else
        let $uri := $uri || '?' || string-join( map:for-each($params, function($key, $value) { $key || "=" || encode-for-uri($value) }), "&amp;")
        return
            http:send-request(<http:request method="GET" href="{$uri}"/>)
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
        jmmc-tap:tap-adql-query($uri, $query, (), $maxrec, $format)

};

(:~
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second.
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @param $votable an optional votable to upload ( use table name prefixed by tap_upload. in your query)
 : @param $format optional format / votable by default
 : @return a VOTable with results for the query (result is cached: see tap-clear-cache() )  or other requested format
 : @error service unavailable, bad response
 :
 :)
declare function jmmc-tap:tap-adql-query($uri as xs:string, $query as xs:string, $votable as node()?, $maxrec as xs:integer?, $format as xs:string?)  {
    jmmc-tap:tap-adql-query($uri, $query, $votable, $maxrec, $format, ())
};

(:~
 : Execute an ADQL query against a TAP service.
 :
 : Warning: CDS set a query limit for the TAP service of max 6 requests per second.
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @param $votable an optional votable to upload ( use table name prefixed by tap_upload. in your query)
 : @param $format optional format / votable by default
 : @param $votable-name optional name to use in the FROM tap_upload.votable-name if table has no name
  : @return a VOTable with results for the query (result is cached: see tap-clear-cache() )  or other requested format
 : @error service unavailable, bad response
 :)
declare function jmmc-tap:tap-adql-query($uri as xs:string, $query as xs:string, $votable as node()?, $maxrec as xs:integer?, $format as xs:string?, $votable-name as xs:string?)  {
let $cache-name := $jmmc-tap:cache-prefix||$uri
let $votable-hash := if(exists($votable)) then "VOTMD5"||util:hash($votable, "md5") else ()
let $cache-key := string-join(($votable-hash,$query,$maxrec,$format))
let $create-cache := cache:create($cache-name, map { "maximumSize": $jmmc-tap:cache-size }) (: TODO:  check that given limit is taken into account was 128 before :)
let $cached := cache:get($cache-name, $cache-key)
    return
        if(exists($cached)) then $cached
        else
            let $res := jmmc-tap:_tap-adql-query($uri, $query, $votable, $maxrec, $format, $votable-name)

            let $error := try {
                if ($res//*:TR) then false() else exists($res//*:INFO[@name='QUERY_STATUS' and @value='ERROR'])
            } catch * {
                false() (: JSON errors seem to be in votable format :)
            }

            let $store := if($error) then () else cache:put($cache-name, $cache-key, $res)
            let $log := if($error) then util:log("error", "error occurs no cache set for "||$cache-name) else util:log("info", "cache set for "||$cache-name)
            let $log := if($error) then util:log("error", "query : " || serialize($query)) else ()
            let $log := if($error) then util:log("error", "result : ") else ()
            let $log := if($error) then util:log("error", $res) else ()
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

(: Convert votable field to sql colname following stilts conventions

:)
declare function jmmc-tap:get-db-colname( $vot-field )
{
    let $field-name := try{ ($vot-field/@name, $vot-field)[1] }catch*{ $vot-field } (: search in votable field or use str param :)
    (: TODO  mimic better stilts conversion see : https://github.com/Starlink/starjava/blob/master/table/src/main/uk/ac/starlink/table/jdbc/JDBCFormatter.java :)
    let $name := replace(lower-case($field-name),"\W+", "_")
    return if($name="publication") then $name||"_" else $name

    (: TODO check reserved keywords ie. DEC !! :)
};

declare function jmmc-tap:get-db-datatype($vot-field)
{

(:    TODO: :)
(:        - add support for V1_1 https://www.ivoa.net/documents/TAP/20180830/PR-TAP-1.1-20180830.html#tth_sEc4.3:)
(:        - support all datatype : boolean bit unsignedByte short int long char unicodeChar float double floatComplex doubleComplex:)
(:        - and votable types https://www.ivoa.net/xml/VOTable/VOTable-1.4.xsd:)
(:        - use timestamp when MJD declared in votable ?:)
(: :)
(: see also
 :   https://www.w3.org/2001/sw/rdb2rdf/wiki/Mapping_SQL_datatypes_to_XML_Schema_datatypes
 :   https://www.postgresql.org/docs/9.1/datatype-numeric.html
 :)

    let $datatype := lower-case($vot-field/@datatype)
    return
        switch ($datatype)
            case "char"
            case "unicodechar"
                return "VARCHAR"
            case "float"
            case "double"
                return "DOUBLE PRECISION"
            case "long"
                return "BIGINT"
            case "int"
            case "short"
                return "INTEGER"

            (: NOT SURE BELOW :)
            case "unsignedbyte"
                return "SMALLINT"

            
            case "boolean"
            case "logical"
            case "bit"
                return "SMALLINT"
            
            case "short"
            case "floatcomplex"
            case "doublecomplex"
                return "                          "|| $datatype

            default
            return $datatype
};


declare %private function jmmc-tap:_get-table-desc( $table-name , $primary-key-name, $votable){
    let $table-name := if(exists($table-name)) then $table-name else $votable//*:TABLE/@name
    let $table-name := jmmc-tap:get-db-colname($table-name) (: normalize table name like a colname :)

    (: use primary-key param as primary key if given to search for the primary field :)
    (: or try to search for a GROUP named primaryKey                                 :)
    let $primary-field :=
        if($primary-key-name)
        then
            ( $votable//*:FIELD[@name=$primary-key-name] , <FIELD datatype="BIGINT" name="{$primary-key-name}"><DESCRIPTION>generated primary key</DESCRIPTION></FIELD> )[1]
        else
            let $primaryKeyGroupRef := $votable//*:GROUP[@name="primaryKey"]/*:FIELDref/@ref

            (: VOTABLE standard tells :
            A GROUP element having the name="primaryKey" attribute defines the primary key of the relation
            by enumerating the ordered list of FIELDrefs that make up the primary key of the table;

            TODO improve to find a way not to use only the first fieldref....
            :)
            return
            if (exists($primaryKeyGroupRef))
            then $votable//*:FIELD[@id=$primaryKeyGroupRef]
            else ()

    (: or a uniq meta.id;meta.main field :)
    let $primary-field := if($primary-field) then $primary-field else
        let $meta_id_main_fields := $votable//*:FIELD[@ucd="meta.id;meta.main"]
(:        let $log := util:log("info", "meta ids : "||string-join($meta_id_main_fields, ", ")):)
        return
            if(count($meta_id_main_fields)=1) then $meta_id_main_fields else ()

    (: or id field :)
    let $primary-field := if($primary-field) then $primary-field else $votable//*:FIELD[@name="id"]

    (: else create a new id field if nothing found :)
    let $primary-field := if($primary-field) then $primary-field else <FIELD datatype="BIGINT" name="id"><DESCRIPTION>default generated primary key</DESCRIPTION></FIELD>

    let $primary-key-name := string($primary-field/@name)

    (: do not return the primary field if it already is in the table :)
    let $primary-field := if( exists($votable//*:FIELD[@name=$primary-key-name]) ) then () else $primary-field


    let $ret := ($table-name, $primary-key-name, $primary-field)
    let $log := util:log("info", $ret)
    return
        $ret
};

declare %private function jmmc-tap:get-db-row-values($tr, $trs-fields, $fields-desc){
    string-join(
        (
            for $td at $pos in $tr/*:TD
            let $datatype := try{$fields-desc($trs-fields[$pos]/@name)?datatype}catch * { util:log("info", " not datatype for field #" || $pos || " (name=" || $trs-fields[$pos]/@name ) }
            return
                switch ($datatype)
                    case "VARCHAR" return concat("'", $td, "'")
                    default return ($td[not(empty(.) or string-length(.)=0) and not(normalize-space(.)=("NaN"))],"NULL")[1] (: avoid empty value for insert VALUE statement :)
        )
        , ", "
    )
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
    %rest:query-param("max", "{$max}", 3)
    function jmmc-tap:votable2sql($vot as document-node()?, $table-name , $primary-key-name, $max)
{

    let $skip-data := try {
        ()
    } catch * {
        false()
    }

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

    let $table-desc := jmmc-tap:_get-table-desc($table-name, $primary-key-name, $vot)
    let $table-name := $table-desc[1]
    let $primary-key-name := $table-desc[2]
    let $primary-column := $table-desc[3]

    let $comments:= ("")
    let $comments := ($comments, if(exists($table-name))  then "Using "||$table-name|| " as table name" else "Missing value for table-name , please add it to VOTABEL@name or as table-name query param")
    let $comments := ($comments, if(exists($primary-column))  then "No primary key given as primary-key-name param, using default : "||$primary-key-name else "Using "||$primary-key-name|| " key as primary key")
    let $comments := ($comments, "","No content extracted, please use the catalog API to injest dat or ask jmmc-tech-group for such enhancement")
    let $comments := ($comments, "","Add max "|| $max|| " records to insert (use max parameter = -1 to insert all records )")
    let $comments := ($comments, "", string-join( for $f at $pos in ($primary-column, $vot//*:FIELD) return jmmc-tap:get-db-colname($f)," | "))

    let $sql-comments := string-join($comments , "&#10;-- ")

    (: create a description map to help associated table creation and future inserts :)
    let $fields-desc := map:merge(
        for $f at $pos in ($primary-column, $vot//*:FIELD)
            let $colname := jmmc-tap:get-db-colname($f)
            let $datatype := if($primary-key-name = $colname) then jmmc-tap:get-db-datatype($f) || " PRIMARY KEY" else jmmc-tap:get-db-datatype($f)
            return map{$pos : map{"colname_prefixed":$pos||"_"||$colname, "colname":$colname , "datatype" : $datatype}}
        )

    let $cols-create :=
        for $f at $pos in ( $primary-column, $vot//*:FIELD )
            let $f := $fields-desc($pos)
            return
                ("  ", "&quot;"||$f?colname||"&quot;", "          ", $f?datatype ) => string-join(" ")

    let $table-create := string-join(( 'CREATE TABLE ' || $table-name
                    , '('
                    , string-join($cols-create, ", &#10;")
                    , ')'
                    ,""
                    ), "&#10;")|| ";"

    (: Insert data looking at TRs if some tr are found limited to max elements :)
    let $max := xs:integer($max)
    let $trs := if ($max >= 0 ) then subsequence($vot//*:TABLEDATA/*:TR,1, $max) else $vot//*:TABLEDATA/*:TR
    let $table-insert := if (exists($trs)) then
                    let $trs-fields := $vot//*:FIELD
                    let $col-names := for $tr-field in $trs-fields return $fields-desc($tr-field/@name)?colname
                    let $trs-values := for $tr at $pos in $trs
                            return
                                '( ' || jmmc-tap:get-db-row-values($tr, $trs-fields, $fields-desc) || ')'
                    return
                        string-join(
                            ( 'INSERT INTO&#10;  "' || $table-name || '" (' || string-join($col-names, ", ") ||')&#10;VALUES&#10;  '
                            || string-join($trs-values, ",&#10;  ")
                            ,"&#10;"
                            ),";&#10;")
                    else
                        ()

    let $sql := string-join(($sql-comments, "", $table-create , "", $table-insert, ""), "&#10;")

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

    let $table-desc := jmmc-tap:_get-table-desc($table-name, $primary-key-name, $vot)
    let $table-name := $table-desc[1]
    let $primary-key-name := $table-desc[2]
    let $primary-column := $table-desc[3]

    let $d := "DELETE FROM &quot;TAP_SCHEMA&quot;.&quot;tables&quot; WHERE table_name='" || $table-name || "';"
    let $i := "INSERT INTO &quot;TAP_SCHEMA&quot;.&quot;tables&quot; VALUES ('public', '"|| $table-name ||"', 'table', '"|| $table-name ||"', NULL);"

    let $delete := "DELETE FROM &quot;TAP_SCHEMA&quot;.&quot;columns&quot; WHERE &quot;table_name&quot;='" || $table-name || "';"
    let $insert := 'INSERT INTO "TAP_SCHEMA"."columns" ("table_name", "column_name", "description", "unit", "ucd", "utype", "datatype", "size", "principal", "indexed", "std", "column_index") VALUES '
    let $cvalues :=
        for $f at $col_index in ( $primary-column, $vot//*:FIELD )
            let $colname := jmmc-tap:get-db-colname($f)
            let $desc := normalize-space(replace($f/*:DESCRIPTION||"", "'", "''"))
            let $unit := $f/@unit||""
            let $ucd := $f/@ucd||""
            let $utype := $f/@utype||""
            (: let $datatype := $f/@datatype NOT properly handled by vollt :)
            let $datatype := tokenize(jmmc-tap:get-db-datatype($f)," ")[1]
            let $size := -1
            let $principal := if($colname=$primary-key-name) then 1 else 0
            let $indexed := if($colname=$primary-key-name) then 1 else 0

            let $v := ($table-name, $colname, $desc, $unit, $ucd, $utype, $datatype, $size, $principal,$indexed,0, $col_index) ! concat("&apos;", ., "&apos;")
        return
            "(" || string-join($v, ", ") || ")"

        return string-join(($d, $i, $delete, $insert, string-join($cvalues, ",&#10;"),""), "&#10;")
};

