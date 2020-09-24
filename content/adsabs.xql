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


declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstract"; 
(: should be http://ads.harvard.edu/schema/abs/1.1/abstracts:)


(: define ads cache collection path to store documents :)
declare variable $adsabs:collection-uri := "/ads/records/";


(: handle token using a cache :)
declare variable $adsabs:cache-name := "adsabs-cache";
declare variable $adsabs:token-cache-name := $adsabs:cache-name || "-token";
declare variable $adsabs:token-cache-value := cache:get($adsabs:cache-name, $adsabs:token-cache-name);
declare variable $adsabs:token := if( exists($adsabs:token-cache-value) ) then $adsabs:token-cache-value else data(collection("/db")//secret-ads-token[1]) ;
(: add basic helper to set token in memory (cache) out of source code :)
declare variable $adsabs:token-check := if ( exists($adsabs:token)) then () else util:log("error", "please save a token element in db or run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXXXXXXXXXXXX')");

(: use a cache for repeated querys :)
declare variable $adsabs:expirable-cache-name := $adsabs:cache-name || "-expirable";
declare variable $adsabs:expirable-cache := cache:create($adsabs:expirable-cache-name,map { "expireAfterAccess": 600000 }); (: 10' :)


(: store server url :)
declare variable $adsabs:ABS_ROOT := "https://ui.adsabs.harvard.edu/abs/";
declare variable $adsabs:API_ROOT := "https://api.adsabs.harvard.edu/v1"; 


declare function adsabs:query( $query-url as xs:string, $query-payload as xs:string?) as xs:string {
    let $key := $query-url || $query-payload
    let $value := cache:get($adsabs:expirable-cache-name, $key)
    return 
        if (exists($value) ) then $value
        else if ( exists($adsabs:token) and $adsabs:token ) then 
            let $log := util:log("info", "query adsabs API on "||$adsabs:API_ROOT||$query-url)
            let $body := if(exists($query-payload)) 
                then
                    <http:body media-type="text/plain">{$query-payload}</http:body>
                else
                    ()
            let $method := if (exists($body)) then "POST" else "GET"
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
        	                let $cache := cache:put($adsabs:expirable-cache-name, $key, $json)
                            return $json
        	            else
        	                (util:log("error",replace(serialize($request), $adsabs:token, "XXXXXXXX")),
        	                util:log("error",serialize($response-head)),
        	                util:log("error", "token is " || $adsabs:token),
        	                fn:error(xs:QName("adsabs:bad-request-1"), $response-head))
        else
            (
                util:log("error", "please run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXX')"),
                fn:error(xs:QName("adsabs:token-not-found"), "please save a token element in db or run cache:put('"||$adsabs:cache-name||"', '" || $adsabs:token-cache-name || "', 'XXXXXXXXXXXXXX')")
            )
};

declare function adsabs:cache-records($records as node()*){
    for $record in $records
        let $resource-name := $record/ads:bibcode || ".xml"
        let $new-doc-path := xmldb:store($adsabs:collection-uri, $resource-name, $record)
        let $fix-perms := sm:chown($new-doc-path, 'guest')
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
 : @return an ads record or empty sequence as node()*
 :)
declare function adsabs:get-records($bibcodes as xs:string*, $use-cache as xs:boolean)
{
    let $cached-records := if ($use-cache) then collection($adsabs:collection-uri)//ads:record[ads:bibcode=$bibcodes] else ()
    
    let $bibcodes-todo := $bibcodes[not(.=$cached-records/ads:bibcode)]
    
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
    
    let $store-in-cache := if ($use-cache) then adsabs:cache-records($new-records) else ()
    
    let $bibcodes-not-done := $bibcodes-todo[not(.=$new-records/ads:bibcode)]
    let $bibcodes-not-requested := $new-records/ads:bibcode[not(.=$bibcodes-todo)]
    let $log := if(exists($bibcodes-not-done)) then util:log("warn", "Missmatch between request and response:&#10;absent bibcodes : (&quot;" || string-join($bibcodes-not-done, "&quot;, &quot;") || "&quot;)" || "&#10;unrequested bibcodes : (&quot;" || string-join($bibcodes-not-requested, "&quot;, &quot;") || "&quot;)") else ()
    
    return
        ($new-records,$cached-records)
};

(:~ 
 : get ads record for the given bibconong cache. 
 : @param $bibcodes  list of given bibcode
 : @return an ads record or empty sequence as node()*
 :)
declare function adsabs:get-records-no-cache($bibcodes as xs:string*)
{
    adsabs:get-records($bibcodes, false())
};

declare function adsabs:get-records($bibcodes as xs:string*)
{
    adsabs:get-records($bibcodes, true())
};


declare function adsabs:get-libraries()
{
    adsabs:query("/biblib/libraries", ())
};

declare function adsabs:search($query as xs:string, $fl as xs:string?)
{
    adsabs:query("/search/query?q="||encode-for-uri($query)
    ||string-join(("",$fl),"&amp;fl=") 
    ||"&amp;rows=2000"
    , ())
};


(: --- GETTER functions :)

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
 : Get first author of given ads record
 : @param $record input ads record 
 : @return first author
 :)
declare function adsabs:get-first-author($record as element()) as xs:string
{
    adsabs:get-authors($record)[1]
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
