xquery version "3.0";


(:~
 : Utility functions to interact with ADS database (or its CDS mirror).
 : 
 : Prefer the use of utility function to retrieved content or use the following namespace to work directly on ads records:
 : declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 
 : Note: get-record and get-record functions always cache retrieved records
 : TODO: add new functions in the API to perform fresh data retrieval. 
 :
 :)
module namespace jmmc-ads="http://exist.jmmc.fr/jmmc-resources/ads";
import module namespace jmmc-cache="http://exist.jmmc.fr/jmmc-resources/cache";
declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 

(: Store server url 
 : harvard is the main server but cds hosts a mirror and is much responsive (avoid blacklist or delay)
 : declare variable $jmmc-ads:ADS_HOST := "http://adsabs.harvard.edu"; :)
declare variable $jmmc-ads:ADS_HOST := "http://cdsads.u-strasbg.fr";

(:
 base of urls to get ads abstract records in xml format.
 Some parameters may be appended to query by authors or bibcodes
 :) 
declare variable $jmmc-ads:abs-accesspoint-url := xs:anyURI($jmmc-ads:ADS_HOST||"//cgi-bin/nph-abs_connect?");
declare variable $jmmc-ads:abs-bibcode-url := xs:anyURI($jmmc-ads:ADS_HOST||"/abs/");


declare variable $jmmc-ads:MONTHS := <months><m><n>Jan</n><v>01</v></m><m><n>Feb</n><v>02</v></m><m><n>Mar</n><v>03</v></m><m><n>Apr</n><v>04</v></m><m><n>May</n><v>05</v></m><m><n>Jun</n><v>06</v></m><m><n>Jul</n><v>07</v></m><m><n>Aug</n><v>08</v></m><m><n>Sep</n><v>09</v></m><m><n>Oct</n><v>10</v></m><m><n>Nov</n><v>11</v></m><m><n>Dec</n><v>12</v></m><m><n>n/a</n><v>01</v></m></months>;

(:  prepare a cache :)
declare variable $jmmc-ads:cache :=
    try {
        let $collection := "/db/apps/jmmc-resources/data/" (: TODO fix this path should be located to the application module data dir :)
        let $filename := "ads-cache.xml"
        let $doc := doc($collection||$filename)
        return if ($doc) then $doc/* else ( doc(xmldb:store($collection, $filename, <ads-cache/>)), sm:chmod(xs:anyURI($collection||$filename),"rwxrwxrwx") )/*
    } catch * {
        error(xs:QName('error'), 'Failed to create cache : ' || $err:description, $err:value)
    };
declare variable $jmmc-ads:cache-insert   := jmmc-cache:insert($jmmc-ads:cache, ?, ?);
declare variable $jmmc-ads:cache-get      := jmmc-cache:get($jmmc-ads:cache, ?);
declare variable $jmmc-ads:cache-keys     := jmmc-cache:keys($jmmc-ads:cache);
declare variable $jmmc-ads:cache-contains := jmmc-cache:contains($jmmc-ads:cache, ?);


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
    let $retrieved := doc($jmmc-ads:abs-bibcode-url||$params)//ads:record
        
    let $cache-insert := for $r in $retrieved return $jmmc-ads:cache-insert($r/ads:bibcode/text(), $r)
    
    return (
        $retrieved
        , for $key in $existing return $jmmc-ads:cache-get($key)
        )
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
    let $url := $jmmc-ads:abs-bibcode-url||encode-for-uri($bibcode)
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
