xquery version "3.0";


(:~
 : Utility functions to interact with ADS database (or its CDS mirror).
 : 
 : Prefer the use of utility function to retrieved content or use the following namespace to work directly on ads records:
 : declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 
 : Note: get-record and get-record functions always cache retrieved records
 : TODO: move to the new API. 

Code snipet to use new API
xquery version "3.1";

let $token := "placehereyourtoken"

let $req := <hc:request href="https://api.adsabs.harvard.edu/v1/export/refabsxml" method="POST">
    <hc:header name="Authorization" value="Bearer {$token}"/>
    <hc:body media-type="application/json"method="text">{{"bibcode": ["2000A&amp;AS..143...41K", "2000A&amp;AS..143...85A", "2000A&amp;AS..143..111G"]}}</hc:body>
</hc:request>

let $response      := hc:send-request($req)
let $response-head := head($response)
let $response-body := tail($response)
let $xml := parse-xml(parse-json(util:binary-to-string($response-body))("export"))
return
    (
        $response-head,
        util:binary-to-string($response-body),
        $xml   
    )

 :
 :)
module namespace jmmc-ads="http://exist.jmmc.fr/jmmc-resources/ads";
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace jmmc-cache="http://exist.jmmc.fr/jmmc-resources/cache";
declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 

(: Store server url 
 : harvard is the main server but cds hosts a mirror and is much responsive (avoid blacklist or delay)
 : declare variable $jmmc-ads:ADS_HOST := "http://adsabs.harvard.edu"; :)
(: declare variable $jmmc-ads:ADS_HOST := "http://cdsads.u-strasbg.fr";:)
 declare variable $jmmc-ads:ADS_HOST := "http://adsabs.harvard.edu"; 
 declare variable $jmmc-ads:ADS_CDS_HOST := "http://cdsads.u-strasbg.fr";

(:
 base of urls to get ads abstract records in xml format.
 Some parameters may be appended to query by authors or bibcodes
 :) 
declare variable $jmmc-ads:abs-bibcode-url := xs:anyURI($jmmc-ads:ADS_CDS_HOST||"/cgi-bin/nph-abs_connect?");
declare variable $jmmc-ads:bibcode-url := xs:anyURI($jmmc-ads:ADS_HOST||"/abs");

declare variable $jmmc-ads:MONTHS := <months><m><n>Jan</n><v>01</v></m><m><n>Feb</n><v>02</v></m><m><n>Mar</n><v>03</v></m><m><n>Apr</n><v>04</v></m><m><n>May</n><v>05</v></m><m><n>Jun</n><v>06</v></m><m><n>Jul</n><v>07</v></m><m><n>Aug</n><v>08</v></m><m><n>Sep</n><v>09</v></m><m><n>Oct</n><v>10</v></m><m><n>Nov</n><v>11</v></m><m><n>Dec</n><v>12</v></m><m><n>n/a</n><v>01</v></m></months>;

(:  prepare a cache :)
declare variable $jmmc-ads:cache-filename := "/db/apps/jmmc-resources/data/ads-cache.xml";
declare variable $jmmc-ads:cache          := doc($jmmc-ads:cache-filename)/ads-cache;
declare variable $jmmc-ads:cache-insert   := jmmc-cache:insert($jmmc-ads:cache, ?, ?);
declare variable $jmmc-ads:cache-get      := jmmc-cache:get($jmmc-ads:cache, ?);
declare variable $jmmc-ads:cache-keys     := jmmc-cache:keys($jmmc-ads:cache);
declare variable $jmmc-ads:cache-contains := jmmc-cache:contains($jmmc-ads:cache, ?);
declare variable $jmmc-ads:cache-flush    := jmmc-cache:flush($jmmc-ads:cache);


(:~ 
 : get ads record for the given bibcode.
 : @param $bibcode given bibcode 
 : @return an ads record or empty sequence
 :)
declare function jmmc-ads:get-record($bibcode as xs:string) as node()?
{
    jmmc-ads:get-records(($bibcode))
};

(:~ 
 : Get ads records for every given bibcode.
 : @param $bibcodes list of bibcodes
 : @return some ads records or empty sequence
 :)
declare function jmmc-ads:get-records($bibcodes as xs:string*) as node()*
{
    let $existing := $bibcodes[.=$jmmc-ads:cache-keys]    

    let $to-retrieve := $bibcodes[not(.=$existing)]
    let $params := string-join(for $b in $to-retrieve return "&amp;bibcode="||encode-for-uri($b),"")
    let $params := $params || "&amp;nr_to_return="||count($to-retrieve) || "&amp;data_type=XML"    
    let $retrieved := if(exists($to-retrieve)) then 
        let $log  := util:log("INFO", "require to query ads for "||string-join($to-retrieve, ", "))
        return doc($jmmc-ads:abs-bibcode-url||$params)//ads:record 
        else ()
        
    let $cache-insert := for $r in $retrieved return $jmmc-ads:cache-insert($r/ads:bibcode/text(), $r)
    
    return (
        $retrieved
        , for $key in $existing return $jmmc-ads:cache-get($key)
        )
};

(:~ 
 : Get ads records for every given bibcode without requesting cache. Used by test-module function.
 : @param $bibcodes list of bibcodes
 : @return some ads records or empty sequence
 :)
declare %private function jmmc-ads:get-records-no-cache($bibcodes as xs:string*) as node()*
{
    let $params := string-join(for $b in $bibcodes return "&amp;bibcode="||encode-for-uri($b),"")
    let $params := $params || "&amp;nr_to_return="||count($bibcodes) || "&amp;data_type=XML"    
    return    
        doc($jmmc-ads:abs-bibcode-url||$params)//ads:record
};

(:~ 
 : Compute the publication date from a given ADS record.
 : @param $record input ads record 
 : @return the publication date
 :)
declare function jmmc-ads:get-pub-date($record as node()) as xs:date
{
  let $pubdate := $record/ads:pubdate/text()
  return jmmc-ads:format-pub-date($pubdate)
};

(:~ 
 : Compute the publication date from a given ADS format date.
 : @param $pubdate publication date in ADS format 
 : @return the publication date
 :)
declare function jmmc-ads:format-pub-date($pubdate as xs:string) as xs:date
{
  let $y := replace($pubdate,'[^\d]','')
  let $m := replace($pubdate,'[\d]| ','')
  return xs:date(concat($y, "-", $jmmc-ads:MONTHS//m[n=$m]/v, "-01"))
};


(:~ 
 : Get first author of given ads record
 : @param $record input ads record 
 : @return first author
 :)
declare function jmmc-ads:get-first-author($record as element()) as xs:string
{
    jmmc-ads:get-authors($record)[1]
};


(:~ 
 : Get keywords of given ads record
 : @param $record input ads record 
 : @return list of keywords
 :)
declare function jmmc-ads:get-keywords($record as element()) as xs:string*
{
    $record//ads:keyword/text()
};

(:~
 : Get list of authors of given ADS record.
 : 
 : @param $record input ADS record
 : @return list of author names
 :)
declare function jmmc-ads:get-authors($record as element()) as xs:string*
{
    $record/ads:author
};

(:~
 : Get the document title from a given ADS record.
 : 
 : @param $record input ADS record
 : @return the document title
 :)
declare function jmmc-ads:get-title($record as element()) as xs:string
{
    $record/ads:title
};

(:~
 : Get the journal information from a given ADS record.
 : 
 : @param $record input ADS record
 : @return the journal information (long name, volume, page)
 :)
declare function jmmc-ads:get-journal($record as element()) as xs:string
{
    $record/ads:journal
};

(:~
 : Get the bibcode from a given ADS record.
 : 
 : @param $record input ADS record
 : @return the associated bibcode
 :)
declare function jmmc-ads:get-bibcode($record as element()) as xs:string
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
declare function jmmc-ads:get-link($bibcode as xs:string, $label as xs:string?) as node()
{
    let $url := $jmmc-ads:bibcode-url||encode-for-uri($bibcode)
    return <a href="{$url}">{if($label) then $label else $bibcode}</a>
};


(:~
 : Display given records in a basic html fragment.
 : This can be used as a rough implementation sample that each application is 
 : adviced to implement for its own presentation.
 : @param $records input ADS records
 : @param $max-autors optional max number of author to display
 : @return html description
 :)
declare function jmmc-ads:get-html($records as element()*, $max-authors as xs:integer?) as element()*
{
    for $record in $records
    return 
        let $bibcode := jmmc-ads:get-bibcode($record)
        let $title := jmmc-ads:get-link($bibcode, jmmc-ads:get-title($record))
        let $year := year-from-date(jmmc-ads:get-pub-date($record))
        let $authors := jmmc-ads:get-authors($record)
        let $suffix  := if (count($authors) gt $max-authors) then " et al."  else ()
        let $authors-str := string-join(subsequence($authors,1,$max-authors),", ") || $suffix        
        let $journal := jmmc-ads:get-journal($record)
        return 
            <span>
                <b>{$title}</b>
                <br/>
                {$authors-str}<br/><b>{$year}</b> - <i>{$journal}</i>
            </span>
            
};

declare
    %test:assertTrue
(:function jmmc-vizier:test-module( ) as xs:boolean {:)
function jmmc-ads:test-module( ) {
    let $rec := jmmc-ads:get-records-no-cache("2017ApJ...844...72W")
    let $title := "Submilliarcsecond Optical Interferometry of the High-mass X-Ray Binary BP Cru with VLTI/GRAVITY"
    let $journal := "The Astrophysical Journal, Volume 844, Issue 1, article id. 72, 17 pp. (2017)."
    let $first-author := "Waisberg, I."
    return
        $title = jmmc-ads:get-title($rec) and $journal = jmmc-ads:get-journal($rec) and $first-author = jmmc-ads:get-first-author($rec)
};
