xquery version "3.0";

(:~
 : Wrapper module to interact with eso archive webportal.
 : 
 :)
module namespace jmmc-eso="http://exist.jmmc.fr/jmmc-resources/eso";

import module namespace jmmc-cache="http://exist.jmmc.fr/jmmc-resources/cache";


declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:  ESO Observation Schedule :)
declare variable $jmmc-eso:eos-url := "http://archive.eso.org/wdb/wdb/eso/sched_rep_arc/query";

(:  prepare a cache :)
declare variable $jmmc-eso:cache-filename := "/db/apps/jmmc-resources/data/eso-cache.xml";
declare variable $jmmc-eso:cache          := doc($jmmc-eso:cache-filename)/eso-cache;
declare variable $jmmc-eso:cache-insert   := jmmc-cache:insert($jmmc-eso:cache, ?, ?);
declare variable $jmmc-eso:cache-get      := jmmc-cache:get($jmmc-eso:cache, ?);
declare variable $jmmc-eso:cache-keys     := jmmc-cache:keys($jmmc-eso:cache);
declare variable $jmmc-eso:cache-contains := jmmc-cache:contains($jmmc-eso:cache, ?);

 (:~
 : Retrieve associated data for the given progid.
 : 
 : @param $progid program id e.g. '093.D-0039(A)'
 : @return the metadada associated to the given progid as a node or empty sequence if progid is empty / eso portal does not return data.
 :)
declare
    %rest:GET
    %rest:path("/jmmc-resources/eso/{$progid}") 
function jmmc-eso:get-meta-from-progid($progid as xs:string*) as node()?
{
  if (string-length($progid)>0) then
      if ($jmmc-eso:cache-contains($progid)) then $jmmc:eso-cache-get($progid) else
      let $url := xs:anyURI($jmmc-eso:eos-url||"?wdbo=html/display&amp;progid="||encode-for-uri($progid))
      let $ua := "Mozilla/5.0 (X11; Linux x86_64; rv:24.0) Gecko/20140903 Firefox/24.0 Iceweasel/24.8.0"
      let $table := httpclient:get( $url, true(), <headers><header name="User-Agent" value="{$ua}"/></headers>)//table[@id="wdbresults1"]
      return try{
        let $meta := for $tr in $table//tr let $label := translate(lower-case($tr/th),"/.?! ","_____") return element {$label} {normalize-space($tr/td)}
        let $record := if($meta[name()="pi_coi"]/text()) then
                            <record created="{current-dateTime()}">
                                <progid>{$progid}</progid>
                                {$meta}
                                {element {"pi"} { tokenize($meta[ name()="pi_coi"], "/")[1]}}
                            </record>
                    else ()
        return $jmmc-eso:cache-insert($progid, $record)
      }catch * {
        $table   
      }
  else 
      ()
};

(:~
 : Retrieve associated metadata for the given progid.
 : This function provides a rest endpoint: /exist/restxq/jmmc-resources/eso/{PROGID}/{METANAME}
 : e.g. '/exist/restxq/jmmc-resources/eso/093.D-0039/pi'
 : @return the associated metadata to the given progid as a string or empty sequence if given progid is empty/not found 
 :)
declare 
    %rest:GET
    %rest:path("/jmmc-resources/eso/{$progid}/{$metaname}")
    %output:method("text")
    %output:media-type("text/plain")
function jmmc-eso:get-meta-from-progid($progid as xs:string, $metaname as xs:string) as xs:string?
{
    jmmc-eso:get-meta-from-progid($progid)/*[name()=$metaname]/text() 
};

(:~
 : Retrieve associated pi for the given progid.
 : This function provides a rest endpoint: 
 : e.g. '/exist/restxq/jmmc-resources/eso/pi?progid=093.D-0039'
 : 
 : @param $progid program id e.g. '093.D-0039(A)'
 : @return the pi associated to the given progid as a string or empty sequence if given progid is empty/not found 
 :)
declare 
    %rest:GET
    %rest:path("/jmmc-resources/eso/pi")
    %rest:query-param("progid", "{$progid}")
    %output:method("text")
    %output:media-type("text/plain")
function jmmc-eso:get-pi-from-progid($progid as xs:string*) as xs:string? 
{
    jmmc-eso:get-meta-from-progid($progid)//pi/text()
};
