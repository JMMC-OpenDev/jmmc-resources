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
declare variable $jmmc-eso:eos-host := "http://archive.eso.org";
declare variable $jmmc-eso:eos-url  := $jmmc-eso:eos-host || "/wdb/wdb/eso/sched_rep_arc/query";

(:  prepare a cache :)
declare variable $jmmc-eso:cache-filename := "/db/apps/jmmc-resources/data/eso-cache.xml";
declare variable $jmmc-eso:cache          := doc($jmmc-eso:cache-filename)/eso-cache;
declare variable $jmmc-eso:cache-insert   := jmmc-cache:insert($jmmc-eso:cache, ?, ?);
declare variable $jmmc-eso:cache-get      := jmmc-cache:get($jmmc-eso:cache, ?);
declare variable $jmmc-eso:cache-keys     := jmmc-cache:keys($jmmc-eso:cache);
declare variable $jmmc-eso:cache-contains := jmmc-cache:contains($jmmc-eso:cache, ?);
declare %private function jmmc-eso:get-table( $query-url as xs:string ){
    let $url := if(starts-with($query-url, "/")) 
        then xs:anyURI($jmmc-eso:eos-host||$query-url) 
        else xs:anyURI($jmmc-eso:eos-url||$query-url)
    let $ua := "Mozilla/5.0 (X11; Linux x86_64; rv:24.0) Gecko/20140903 Firefox/24.0 Iceweasel/24.8.0"
    return httpclient:get( $url, true(), <headers><header name="User-Agent" value="{$ua}"/></headers>)//table[@id="wdbresults1"]  
};

 (:~
 : Retrieve associated data for the given progid.
 : @note
 : a warning may be inserted if given progid get multiple entries on eso side (eg. '093.D-0316(A)').
 : first record is taken as reference ( and put in cache ).
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
      if ($jmmc-eso:cache-contains($progid)) then $jmmc-eso:cache-get($progid) else
      let $table := jmmc-eso:get-table("?wdbo=html/display&amp;progid="||encode-for-uri($progid))
      (: use soft rule to detect that this progid get multiple results :)
      let $multiple := if($table//TR[@id]) then <warning>this progid gets multiple records in the eso archive<url>{$table//TR[@id="1"]/td[1]/a/@href/string()}</url></warning> else ()
      let $table := if($multiple) then     (: new url is in the first row, first column:)
          jmmc-eso:get-table( $multiple/url )
          else 
              $table 
      return try{
        let $meta := for $tr in $table//tr let $label := translate(lower-case($tr/th),"/.?! ","_____") return element {$label} {normalize-space($tr/td)}
        let $record := if($meta[name()="pi_coi"]/text()) then
                            <record created="{current-dateTime()}">
                                <progid>{$progid}</progid>
                                {$meta}
                                {element {"pi"} { tokenize($meta[ name()="pi_coi"], "/")[1]}}
                                {$multiple}
                            </record>
                    else ()
        return $jmmc-eso:cache-insert($progid, $record)
      }catch * {
        error(xs:QName('jmmc-eso:get-meta-from-progid'), 'Failed to retrieve data for progid='|| $progid) 
        (: <error>{$table,$multiple}</error> :)
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
