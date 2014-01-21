xquery version "3.0";


(:~
 : Utility functions to interact with oival remote service;
 :)
module namespace jmmc-oival="http://exist.jmmc.fr/jmmc-resources/oival";


declare variable $jmmc-oival:serviceAccesspointUrl := xs:anyURI('http://apps.jmmc.fr/oival/oival.php');

declare function jmmc-oival:checkUrl($url)
{
    let $fields :=  <httpclient:fields>
                        <httpclient:field name="url" value="{$url}" type="string"/>        
                    </httpclient:fields>
    let $postResponse := httpclient:post-form($jmmc-oival:serviceAccesspointUrl, $fields, false(), ())
    return
    $postResponse
};