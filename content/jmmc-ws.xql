xquery version "3.1";

(:~
 : This module wraps some JMMC webservices.
 :
 :
 :)
module namespace jmmc-ws="http://exist.jmmc.fr/jmmc-resources/ws";


declare variable $jmmc-ws:cache-prefix := "_jmmc-ws-cache-";




(:~
 : ut_ngs_score wrapper function.
 :
 : @param $input-array data input array [[a,b,c]...].
 : @return an array with ranking scores for each line of the input array.
 :)
declare function jmmc-ws:pyws-ut_ngs_score($input-array){
    let $resp := jmmc-ws:post-json("https://pyws.jmmc.fr/ut_ngs_score", $input-array)
    return $resp?*
};


(:~
: Query GetStar for given identifier and provide result as a VOTABLE.
: see : https://www.jmmc.fr/getstar
:)
declare function jmmc-ws:getstar($identifiers as xs:string*){
    let $starparam := string-join($identifiers, ",")
    let $url := "https://astroquery.jmmc.fr/getstar?star="|| encode-for-uri($starparam)
    let $log := util:log("info", "query "|| $url )

    let $cache-name := $jmmc-ws:cache-prefix||"getstar"
    let $cached := cache:get($cache-name, $url)
    return
        if(exists($cached)) then
            $cached
        else
            try{
            let $votable := doc($url)
            let $cache := cache:put($cache-name, $url, $votable)
            return
                $votable
            } catch * {
                <error> { $err:code, $err:description, $err:value, " module: ", $err:module, "(", $err:line-number, ",", $err:column-number, ")" } </error>
            }
};


declare function jmmc-ws:post-json( $url, $payload ) {
    let $req :=
        <hc:request href="{$url}" method="POST">
            <hc:header name="Content-Type" value="application/json"/>
            <hc:body media-type="text/plain">{serialize($payload,  map { 'method':'json'})}</hc:body>
        </hc:request>
    let $resp := hc:send-request($req)
    let $response-head := head($resp)
    let $response-body := tail($resp)
    return
            if ($response-head/@status = ("200","404"))
            then
                let $json := util:binary-to-string($response-body)
                return parse-json($json)
            else
                (
                util:log("error",serialize($response-head)),
                util:log("error",serialize(util:base64-decode($response-body))),
                fn:error(xs:QName("jmmc-ws:bad-request"), $response-head/@status ||":"|| $response-head/@message))
};

