xquery version "3.0";

(:~
 : Module wrapping oiexplorer existdb extension.
 :)

module namespace jmmc-oiexplorer="http://exist.jmmc.fr/jmmc-resources/oiexplorer";

import module namespace oi="http://exist.jmmc.fr/extension/oiexplorer" at "java:fr.jmmc.exist.OIExplorerModule";
declare namespace java-io-file="java:java.io.File";

declare function jmmc-oiexplorer:to-xml-base64($file as xs:base64Binary?){
    let $login:=xmldb:login("", "admin", "gapi")
    
    (: TODO : push out this nasty code :)
    let $tmp := java-io-file:create-temp-file("jmmc-oiexplorer", "validate")
    let $path := java-io-file:get-absolute-path($tmp)
    let $op1 := file:serialize-binary($file, $path)    
    
    let $res := oi:to-xml($path)    
    
    let $op2 := java-io-file:delete($tmp)
    
    return $res
};

declare function jmmc-oiexplorer:to-xml($filename as xs:string?){
    oi:to-xml($filename)
};