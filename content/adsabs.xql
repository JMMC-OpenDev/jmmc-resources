xquery version "3.1";

(:~
 : Utility functions to interact with ADSABS database using their API.
 : ( https://github.com/adsabs/adsabs-dev-api )
 :
 : Since a barear token is required please set it in cache or store in to module/data/adsabs.xml .
 :
 : Prefer the use of getter to retrieve result's content or use the following namespace to work directly on ads records:
 : declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts";
 :
 : Note: get-record and get-record functions always cache retrieved records
 :
 :)

module namespace adsabs="http://exist.jmmc.fr/jmmc-resources/adsabs";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";


declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts";

(: define ads cache collection path to store documents :)
declare variable $adsabs:collection-uri := "/db/ads/records/";
(: TODO add reset function for dba ?
 :  let $collection-uri := "/db/ads/records"
 :  for $resource in xmldb:get-child-resources($collection-uri) return xmldb:remove($collection-uri, $resource)
:)

(: consider some journal as non refereed even marked as refereed on ADS side :)
declare variable $adsabs:filtered-journals := ("SPIE", "ASPC", "PhDT", "arXiv", "MNRAS.tmp");



(: handle token using a cache :)
declare variable $adsabs:cache-name := "adsabs-cache";
declare variable $adsabs:token-cache-name := $adsabs:cache-name || "-token";
declare variable $adsabs:token-cache-value := cache:get($adsabs:cache-name, $adsabs:token-cache-name);
declare variable $adsabs:token := if( exists($adsabs:token-cache-value) ) then $adsabs:token-cache-value else data(collection("/db")//ads-token[not(.="ReplaceWithYourToken")])[1] ;
(: add basic helper to set token in memory (cache) out of source code :)
declare variable $adsabs:token-check := if ( exists($adsabs:token)) then () else util:log("error", "please save a token element in db or run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXXXXXXXXXXXX')");

(: use a cache for repeated querys :)
declare variable $adsabs:expirable-cache-name := $adsabs:cache-name || "-queries";
(: cache:clear or cache:remove can be asked on demand on updates, else cache get expirarion delay :)
declare variable $adsabs:expirable-cache := cache:create($adsabs:expirable-cache-name,map { "expireAfterAccess": 3600000 }); (: 1h :)


(: store server url :)
declare variable $adsabs:ABS_ROOT := "https://ui.adsabs.harvard.edu/abs/";
declare variable $adsabs:SEARCH_ROOT := "https://ui.adsabs.harvard.edu/search/";
declare variable $adsabs:API_ROOT := "https://api.adsabs.harvard.edu/v1";


declare variable $adsabs:MONTHS := <months><m><n>Jan</n><v>01</v></m><m><n>Feb</n><v>02</v></m><m><n>Mar</n><v>03</v></m><m><n>Apr</n><v>04</v></m><m><n>May</n><v>05</v></m><m><n>Jun</n><v>06</v></m><m><n>Jul</n><v>07</v></m><m><n>Aug</n><v>08</v></m><m><n>Sep</n><v>09</v></m><m><n>Oct</n><v>10</v></m><m><n>Nov</n><v>11</v></m><m><n>Dec</n><v>12</v></m><m><n>n/a</n><v>01</v></m></months>;


declare function adsabs:query( $query-url as xs:string, $query-payload as xs:string?) as xs:string {
    adsabs:query( $query-url, $query-payload, true())
};

declare function adsabs:query( $query-url as xs:string, $query-payload as xs:string?, $use-cache as xs:boolean) as xs:string {
    adsabs:query( $query-url, $query-payload, $use-cache, "POST")
};

declare function adsabs:query-update( $query-url as xs:string, $query-payload as xs:string?, $use-cache as xs:boolean) as xs:string {
    adsabs:query( $query-url, $query-payload, $use-cache, "PUT")
};

declare function adsabs:query( $query-url as xs:string, $query-payload as xs:string?, $use-cache as xs:boolean, $method-if-payload as xs:string) as xs:string {

    let $key := $query-url || $query-payload
    let $value := if($use-cache) then cache:get($adsabs:expirable-cache-name, $key) else ()
    return
        if (exists($value) ) then $value
        else if ( exists($adsabs:token) and $adsabs:token ) then
            let $log := util:log("info", "query adsabs API on "||$adsabs:API_ROOT||$query-url)
            let $body := if(exists($query-payload))
                then
                    <http:body media-type="text/plain">{$query-payload}</http:body>
                else
                    ()
            let $method := if (exists($body)) then $method-if-payload else "GET"
            let $request :=
        		<http:request method="{$method}" href="{$adsabs:API_ROOT}{$query-url}">
        			<http:header name="Authorization" value="Bearer:{$adsabs:token}"/>
            		<http:header name="Content-Type" value="application/json"/>
            		{$body}
        		</http:request>
        	return
        		let $response := http:send-request($request)
        		let $response-head := head($response)
                let $response-body := tail($response)
        	    return
        	            if ($response-head/@status = ("200","404"))
        	            then
        	                let $json := util:binary-to-string($response-body)
        	                let $cache := cache:put($adsabs:expirable-cache-name, $key, $json) (: always cache last result :)
                            return $json
        	            else
        	                (util:log("error",replace(serialize($request), $adsabs:token, "XXXXXXXX")),
        	                util:log("error",serialize($response-head)),
        	                util:log("error",serialize($response-body)),
(:        	                util:log("error", "token is " || $adsabs:token),:)
        	                fn:error(xs:QName("adsabs:bad-request-1"), $response-head/@status ||":"|| $response-head/@message))
        else
            (
                util:log("error", "please run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXX')"),
                fn:error(xs:QName("adsabs:token-not-found"), "please save a token element in db or run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXXXXXXXXXXXX')")
            )
};



(:declare %private function adsabs:cache-citations($bibcode as xs:string, $citations as xs:string*):)
(:{:)
(:    let $citations-root := collection("/ads")//citations:)
(:    let $citation-root := if( exists($citations-root/citation[@bibcode=$bibcode]) ) then () else update insert <citation bibcode="{$bibcode}"/> into $citations-root:)
(:    let $citation-root := $citations-root/citation[@bibcode=$bibcode]:)
(:    :)
(:    for $citation in $citations return update insert <bibcode>{$citation}</bibcode> into $citation-root:)
(:};:)

(:~
 : Get refereed ads citations for the given bibcodes using cache or not.
 : @param $bibcodes  list of given bibcode
 : @param $use-cache use cache or not.
 : @return ads citations or empty sequence as node()*
 :)
declare function adsabs:get-citations($bibcodes as xs:string*, $refereed as xs:boolean, $use-cache as xs:boolean) as xs:string*
{
(:    let $cached-citations := if ($use-cache) then collection("/ads")//citations/citation[@bibcode=$bibcodes] else ():)
(:    let $bibcodes-todo := if($use-cache) then let $cached-bibcodes := $cached-citations/@bibcode/string() return $bibcodes[not(.=$cached-bibcodes)] else $bibcodes:)

    (: TODO perform a load test to check limit of returned citations 2000 ? :)
(:    let $new-citations := if ( exists($bibcodes-todo) ) then :)
(:        for $bibcode in $bibcodes-todo:)
        for $bibcode in $bibcodes
        let $q := "citations(identifier:"|| $bibcode ||")" || " property:refereed"[$refereed]
        let $search := adsabs:search($q, 'bibcode', $use-cache)
        let $bibcodes := adsabs:ignore-bad-refereed-bibcode($search?response?docs?*?bibcode)
(:        let $store-in-cache := if ($use-cache and exists($bibcodes)) then adsabs:cache-citations($bibcode, $bibcodes) else () (: we miss here to update new old citations if use-cache is false, should we enhance code ?:):)
        return
            $bibcodes
(:        else :)
(:            ():)
(:    return:)
(:        ($new-citations,$cached-citations/bibcode) :)
};

declare function adsabs:get-refereed-citations($bibcodes as xs:string*) as xs:string*
{
    adsabs:get-citations($bibcodes, true(), true())
};


declare %private function adsabs:cache-records($records as node()*){
    for $record in $records
        let $resource-name := $record/ads:bibcode || ".xml"
        let $new-doc-path := xmldb:store($adsabs:collection-uri, $resource-name, $record)
        let $fix-perms := try { sm:chown($new-doc-path, 'guest') } catch * {()}
        let $log := util:log("info", "cache "|| $resource-name)
        return
            ()
};

(:~
 : get ads record for the given bibcodes using cache or not.
 : we could get other format than refabsxml https://github.com/adsabs/adsabs-dev-api/blob/master/Export_API.ipynb
 : but this one contains most informations
 : @param $bibcodes  list of given bibcode
 : @param $use-cache use cache or not.
 : @return ads records or empty sequence as node()*
 :)
declare function adsabs:get-records($bibcodes as xs:string*, $use-cache as xs:boolean)
{
    let $cached-records := if ($use-cache) then collection($adsabs:collection-uri)//ads:record[ads:bibcode=$bibcodes] else ()
    let $bibcodes-todo := if($use-cache) then let $cached-bibcodes := $cached-records/ads:bibcode/string() return $bibcodes[not(.=$cached-bibcodes)] else $bibcodes

    (: TODO perform a load test to check limit of returned records 2000 ? :)
    let $new-records := if ( exists($bibcodes-todo) ) then
        let $quoted-bibcodes-todo := for $b in $bibcodes-todo return "&quot;"||$b||"&quot;"
        let $payload := '{"bibcode": [' || string-join($quoted-bibcodes-todo, ", ") || "]}"
        let $json-resp := adsabs:query("/export/refabsxml",$payload)
        let $json-resp-export := parse-json($json-resp)?export
        return
            parse-xml($json-resp-export)//ads:record
        else
            ()

    let $store-in-cache := if ($use-cache) then adsabs:cache-records($new-records) else () (: we miss here to update new old records if use-cache is false, should we enhance code ?:)

    let $bibcodes-not-done := $bibcodes-todo[not(.=$new-records/ads:bibcode)]
    let $bibcodes-not-requested := $new-records/ads:bibcode[not(.=$bibcodes-todo)]
    let $log := if(exists($bibcodes-not-done)) then util:log("warn", "Missmatch between request and response:&#10;absent bibcodes : (&quot;" || string-join($bibcodes-not-done, "&quot;, &quot;") || "&quot;)" || "&#10;unrequested bibcodes : (&quot;" || string-join($bibcodes-not-requested, "&quot;, &quot;") || "&quot;)") else ()

    return
        ($new-records,$cached-records)
};

(:~
 : Get ads record for the given bibcode cache (no-cache).
 : @param $bibcodes  list of given bibcode
 : @return an ads record or empty sequence as node()*
 :)
declare function adsabs:get-records-no-cache($bibcodes as xs:string*)
{
    adsabs:get-records($bibcodes, false())
};

(:~
 : Get ads record for the given bibcode cache.
 : @param $bibcodes  list of given bibcode
 : @return ads records or empty sequence as node()*
 :)
declare
    %rest:GET
    %rest:path("/adsabs")
    %rest:query-param("bibcodes", "{$bibcodes}")
function adsabs:get-records($bibcodes as xs:string*)
{
    adsabs:get-records($bibcodes, true())
};


declare function adsabs:get-libraries()
{
    adsabs:get-libraries(true())
};

declare function adsabs:get-libraries($use-cache as xs:boolean)
{
    parse-json(adsabs:query("/biblib/libraries", (), $use-cache))
};

declare function adsabs:libraries-diff($primary-id, $secondary-ids)
{
    let $action := "difference"
    let $payload := '{"action":"'||$action||'" ,"libraries": [' || string-join(for $id in $secondary-ids return "&quot;"||$id||"&quot;", ", ") || "]}"
    return
        parse-json(adsabs:query("/biblib/libraries/operations/"||$primary-id, $payload, false()))
};


declare function adsabs:library($name-or-id)
{
    adsabs:library($name-or-id, true())
};
declare function adsabs:library($name-or-id, $use-cache as xs:boolean)
{
    let $id := adsabs:get-libraries()?*?*[?name=$name-or-id or ?id=$name-or-id]?id
    return parse-json(adsabs:query("/biblib/libraries/"||$id, (), $use-cache))
};
declare function adsabs:library-id($name){
    adsabs:get-libraries()?libraries?*[?public=true() and ?name[.=$name] ]?id
};

declare function adsabs:library-query($name){
    "docs(library/"||adsabs:library-id($name)||")"
};

declare function adsabs:library-get-permissions($name-or-id)
{
    adsabs:library-get-permissions($name-or-id, true())
};

declare function adsabs:library-get-permissions($name-or-id, $use-cache as xs:boolean)
{
    let $id := adsabs:get-libraries()?*?*[?name=$name-or-id or ?id=$name-or-id]?id
    return parse-json(adsabs:query("/biblib/permissions/"||$id, (), $use-cache))
};

(:~
 : Manage collaborators on the list.
 : Set admin, read and write to false to revoke a collaborator.
:)
declare function adsabs:library-set-permissions($name-or-id, $email as xs:string, $read as xs:boolean, $write as xs:boolean, $admin as xs:boolean)
{
    let $id := adsabs:get-libraries()?*?*[?name=$name-or-id or ?id=$name-or-id]?id
    let $payload := '{"email":"'||$email||'","permission":{"read":'||$read||',"write":'||$write||',"admin":'||$admin||'}}'
    return
        parse-json(adsabs:query("/biblib/permissions/"||$id, $payload, false()))
};


declare function adsabs:library-get-bibcodes($name-or-id)
{
    adsabs:library-get-bibcodes($name-or-id, true())
};

declare function adsabs:library-get-bibcodes($name-or-id, $use-cache as xs:boolean)
{
    data(adsabs:search(adsabs:library-get-search-expr($name-or-id), "bibcode", $use-cache)?response?docs?*?bibcode)
};

declare function adsabs:library-get-search-expr($name-or-id)
{
    let $id := adsabs:get-libraries()?*?*[?name=$name-or-id or ?id=$name-or-id]?id
    return "docs(library/"||$id||")"
};



declare function adsabs:create-library($name as xs:string, $description  as xs:string, $public as xs:boolean, $bibcodes as xs:string*){
    let $quoted-bibcodes-todo := for $b in $bibcodes return "&quot;"||$b||"&quot;"
    let $payload := '{"name":"'||$name||'" ,"description":"'||$description||'" ,"public":'||$public||' ,"bibcode": [' || string-join($quoted-bibcodes-todo, ", ") || "]}"
    let $log := util:log("info", "creating library "|| $name)
    return
        parse-json(adsabs:query("/biblib/libraries", $payload, false()))
};

declare function adsabs:update-library($id as xs:string, $name as xs:string?, $description  as xs:string?, $public as xs:boolean?){
    let $payload := '{'||string-join(
        ( ('"name":"'||$name||'"')[exists($name)], ('"description":"'||$description||'"')[exists($description)] , ('"public":'||$public)[exists($public)] )
        ,", ")||'}'
    return
        parse-json(adsabs:query-update("/biblib/documents/"||$id, $payload, false()))
};
(: add -X DELETE equ. for delete-library($id) :)

declare function adsabs:library-add($name-or-id, $bibcodes){
    adsabs:library-add-or-remove($name-or-id, $bibcodes, "add")
};

declare function adsabs:library-remove($name-or-id, $bibcodes){
  adsabs:library-add-or-remove($name-or-id, $bibcodes, "remove")
};

declare function adsabs:library-clear($name-or-id){
    (: todo : try to mimic empty action   :)
    let $bibcodes := adsabs:library-get-bibcodes($name-or-id, false())
    return
        adsabs:library-add-or-remove($name-or-id, $bibcodes, "remove")
};


declare %private function adsabs:library-add-or-remove($name-or-id, $bibcodes, $action){
    if ($bibcodes) then
        let $quoted-bibcodes-todo := for $b in $bibcodes return "&quot;"||$b||"&quot;"
        let $payload := '{"action":"'||$action||'" ,"bibcode": [' || string-join($quoted-bibcodes-todo, ", ") || "]}"
        let $id := adsabs:get-libraries()?*?*[?name=$name-or-id or ?id=$name-or-id]?id
        return
            parse-json(adsabs:query("/biblib/documents/"||$id, $payload, false()))
    else
        util:log("info", "Skipping action on library " || $name-or-id || ". no bibcode provided for "||$action)

};

declare function adsabs:search-bibcodes($query) as xs:string*{
    adsabs:search($query, "bibcode")?response?docs?*?bibcode
};

(: Search without using cache :)
declare function adsabs:search($query as xs:string, $fl as xs:string?)
{
    adsabs:search($query, $fl, true())
};

declare function adsabs:search($query as xs:string, $fl as xs:string?, $use-cache as xs:boolean)
{
    parse-json(
        adsabs:query("/search/query?q="||encode-for-uri($query)
    ||string-join(("",for $f in $fl return encode-for-uri($f)),"&amp;fl=")
    ||"&amp;rows=2000"
    , (), $use-cache)
    )
};

declare function adsabs:search-map($params as map(*), $use-cache as xs:boolean)
{
    let $params-keys := map:keys($params)
    let $defaults := (
        if(exists($params-keys[starts-with(., "facet.")])) then map{"facet":"true"} else ()
        ,map{"wt":"xml"}
    )
    let $params := map:merge(($defaults,$params)) (: params values have higher priority on last merged position:)
    let $query-params := "?" || string-join(map:for-each($params, function($k, $v){string-join(($k, encode-for-uri($v)), "=")}), "&amp;")
    return
    parse-json(
        adsabs:query("/search/query"||$query-params, (), $use-cache)
    )
};



(: --- GETTER functions :)

declare %private function adsabs:ignore-bad-refereed-bibcode($bibcodes as xs:string*) {
    $bibcodes[not( substring(., 5, 4)=$adsabs:filtered-journals)]
};

(:~
 : Indicates a refereed paper.
 : Some journals are flaged as non refereed.
 : @param $record input ads record
 : @return true if refereed, false else
 :)
declare function adsabs:is-refereed($record as node()) as xs:boolean
{
  $record/@article="true" and exists( adsabs:ignore-bad-refereed-bibcode($record/ads:bibcode) )
};

(:~
 : Compute the publication year date from a given ADS record.
 : @param $record input ads record
 : @return the publication date
 :)
declare function adsabs:get-pub-year($record as node()) as xs:integer
{
     year-from-date(adsabs:get-pub-date($record))
(:  substring($record/ads:pubdate,1,4):)
};
(:~
 : Compute the publication date from a given ADS record.
 : @param $record input ads record
 : @return the publication date
 :)
declare function adsabs:get-pub-date($record as node()) as xs:date
{
  let $pubdate := $record/ads:pubdate/text()
  return adsabs:format-pub-date($pubdate)
};

(:~
 : Compute the publication date from a given ADS format date.
 : @param $pubdate publication date in ADS format
 : @return the publication date
 :)
declare function adsabs:format-pub-date($pubdate as xs:string) as xs:date
{
  let $y := replace($pubdate,'[^\d]','')
  let $m := replace($pubdate,'[\d]| ','')
  return xs:date(concat($y, "-", $adsabs:MONTHS//m[n=$m]/v, "-01"))
};


(:~
 : Get the abstract of given ads record
 : @param $record input ads record
 : @return abstract of publication or empty sequence
 :)
declare function adsabs:get-abstract($record as element()) as xs:string?
{
    $record/ads:abstract
};

(:~
 : Get type of given ads record
 : @param $record input ads record
 : @return type of publication
 :)
declare function adsabs:get-type($record as element()) as xs:string
{
    $record/@type/text()
};

(:~
 : Get keywords of given ads record
 : @param $record input ads record
 : @return list of keywords
 :)
declare function adsabs:get-keywords($record as element()) as xs:string*
{
    $record//ads:keyword/text()
};
(:~
 : Get first author of given ads record
 : @param $record input ads record
 : @return first author
 :)
declare function adsabs:get-first-author($record as element()) as xs:string
{
    adsabs:get-authors($record)[1]
};

(:~
 : Get list of authors of given ADS record.
 :
 : @param $record input ADS record
 : @return list of author names
 :)
declare function adsabs:get-authors($record as element()) as xs:string*
{
    $record/ads:author
};

(:~
 : Get the document title from a given ADS record.
 :
 : @param $record input ADS record
 : @return the document title
 :)
declare function adsabs:get-title($record as element()) as xs:string
{
    $record/ads:title
};

(:~
 : Get the journal information from anoADS record.
 :
 : @param $record input ADS record
 : @return the journal information (long name, volume, page)
 :)
declare function adsabs:get-journal($record as element()) as xs:string
{
    $record/ads:journal
};
(:~
 : Get the volume information from an ADS record.
 :
 : @param $record input ADS record
 : @return the associated volume or empty sequence
 :)
declare function adsabs:get-volume($record as element()) as xs:string?
{
    $record/ads:volume
};

(:~
 : Get the pages information from an ADS record.
 :
 : @param $record input ADS record
 : @return the associated pages
 :)
declare function adsabs:get-pages($record as element()) as xs:string
{
    string-join( ( $record/ads:page, $record/ads:lastpage ), "-" )
};

(:~
 : Get the bibcode from a given ADS record.
 :
 : @param $record input ADS record
 : @return the associated bibcode
 :)
declare function adsabs:get-bibcode($record as element()) as xs:string
{
    $record/ads:bibcode
};

(:~
 : Get the doi from a given ADS record if any.
 :
 : @param $record input ADS record
 : @return the associated DOI
 :)
declare function adsabs:get-doi($record as element()) as xs:string?
{
    $record/ads:DOI
};



(:~
 : Get the astract link for a given bibcode.
 :
 : @param $bibcode bibcode
 : @param $label optionnal link text (use bibcode by default)
 : @return the html link onto the ADS abstract service
 :)
declare function adsabs:get-link($bibcode as xs:string, $label as item()*) as node()
{
    let $url := $adsabs:ABS_ROOT||encode-for-uri($bibcode)||"/abstract"
    return <a href="{$url}">{if(exists($label)) then $label else $bibcode}</a>
};

(:~
 : Get the query link.
 :
 : @param $query query
 : @param $label optionnal link text else use query value
 : @return the html link onto the ADS abstract service
 :)
declare function adsabs:get-query-link($query as xs:string, $label as item()*) as node()
{
    adsabs:get-query-link($query, $label, ())
};

(:~
 : Get the query link.
 :
 : @param $query query
 : @param $label optionnal link text else use query value
 : @param $params optionnal params to give to the query. values must be encoded for uri ("param1=value1", "param2=value2")
 : @return the html link onto the ADS abstract service
 :)
declare function adsabs:get-query-link($query as xs:string, $label as item()*, $params as xs:string*) as node()
{
    let $q:="q="||encode-for-uri($query)
    let $url := $adsabs:SEARCH_ROOT||string-join(($q, $params), "&amp;")
    return <a target="_blank" href="{$url}">{if(exists($label)) then $label else $query}</a>
};

(:~
 : Display given records in a basic html fragment.
 : This can be used as a rough implementation sample that each application is
 : adviced to implement for its own presentation.
 : @param $records input ADS records
 : @param $max-autors optional max number of author to display
 : @return html description
 :)
declare function adsabs:get-html($records as element()*, $max-authors as xs:integer?) as element()*
{
    for $record in $records
    return
        let $bibcode := adsabs:get-bibcode($record)
        let $title := adsabs:get-link($bibcode, adsabs:get-title($record))
        let $year := year-from-date(adsabs:get-pub-date($record))
        let $authors := adsabs:get-authors($record)
        let $suffix  := if (count($authors) gt $max-authors) then " et al."  else ()
        let $authors-str := string-join(subsequence($authors,1,$max-authors),", ") || $suffix
        let $journal := adsabs:get-journal($record)
        return
            <span>
                <b>{$title}</b>
                <br/>
                {$authors-str}<br/><b>{$year}</b> - <i>{$journal}</i>
            </span>

};


declare function adsabs:get-bibtex($records as element()*){
    let $bibrecs :=
        for $r in $records
            let $pubid :=  $r/ads:bibcode
            let $type := "@" || upper-case($r/@type)
            let $attributes := map{
                "title" : $r/ads:title,
                "authors" : string-join(adsabs:get-authors($r),"&#10;and "),
                "journal" : adsabs:get-journal($r),
                "abstract": adsabs:get-abstract($r),
                "volume"  : adsabs:get-volume($r),
                "pages"   : adsabs:get-pages($r),
                "year"    : adsabs:get-pub-year($r),
                "doi"     : adsabs:get-doi($r),
                "optnode" : $pubid || " 7ici"
            }
            return
                string-join(
                    ( $type||'{'||$pubid, map:for-each( $attributes, function($k,$v){if($v) then upper-case($k)|| " = {" || $v ||"}" else () } ), '}'),
                    ",&#10;"
                    )
(:        $volume,$pages,,:)
    return string-join($bibrecs, "&#10;&#10;")
};

declare
    %test:assertTrue
function adsabs:test-module( ) {
    let $debug := false()
    let $rec := adsabs:get-records-no-cache("2017ApJ...844...72W")
(:    let $rec := adsabs:get-records("2017ApJ...844...72W"):)
    let $title := "Submilliarcsecond Optical Interferometry of the High-mass X-Ray Binary BP Cru with VLTI/GRAVITY"
    let $journal := "The Astrophysical Journal, Volume 844, Issue 1, article id. 72, 17 pp. (2017)."
    let $first-author := "Waisberg, I."
    return
        (
            $title = adsabs:get-title($rec) and $journal = adsabs:get-journal($rec) and $first-author = adsabs:get-first-author($rec),
            string-join(($title, $journal, $first-author), "   |")[$debug],
            string-join((adsabs:get-title($rec),adsabs:get-journal($rec),adsabs:get-first-author($rec)),"   |")[$debug]
        )
};

