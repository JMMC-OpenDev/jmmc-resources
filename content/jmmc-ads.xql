xquery version "3.0";


(:~
 : Utility functions to interact with ADS database (or its CDS mirror).
 : 
 : Prefer the use of utility function to retried content or use the following namespace to work directly on ads records:
 : declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 
 :)
module namespace jmmc-ads="http://exist.jmmc.fr/jmmc-resources/ads";
declare namespace ads="http://ads.harvard.edu/schema/abs/1.1/abstracts"; 

(: Store server url 
 : harvard is the main server but cds hosts a mirror and is much responsive (avoid blacklist or delay)
 : declare variable $jmmc-ads:ADS_HOST := "http://adsabs.harvard.edu"; :)
declare variable $jmmc-ads:ADS_HOST := "http://cdsads.u-strasbg.fr";

(:
 base of urls to get ads abstract records in xml format.
 Some parameters may be appended to query by authors or bibcodes
 :) 
declare variable $jmmc-ads:abs-accesspoint-url := xs:anyURI($jmmc-ads:ADS_HOST||"//cgi-bin/nph-abs_connect?data_type=XML");


declare variable $jmmc-ads:MONTHS := <months><m><n>Jan</n><v>01</v></m><m><n>Feb</n><v>02</v></m><m><n>Mar</n><v>03</v></m><m><n>Apr</n><v>04</v></m><m><n>May</n><v>05</v></m><m><n>Jun</n><v>06</v></m><m><n>Jul</n><v>07</v></m><m><n>Aug</n><v>08</v></m><m><n>Sep</n><v>09</v></m><m><n>Oct</n><v>10</v></m><m><n>Nov</n><v>11</v></m><m><n>Dec</n><v>12</v></m><m><n>n/a</n><v>01</v></m></months>;



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
    let $params := string-join(for $b in $bibcodes return "&amp;bibcode="||encode-for-uri($b),"")
    let $params := $params || "&amp;nr_to_return="||count($bibcodes)
    return doc($jmmc-ads:abs-accesspoint-url||$params)//ads:record
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
    $record/ads:author[1]
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




