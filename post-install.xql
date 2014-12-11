xquery version "1.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(: fix permission of cache so everybody can get their requests cached :)
let $op := sm:chmod( xs:anyURI(concat($target,"/data/eso-cache.xml")), "rw-rw-rw-")
let $op := sm:chmod( xs:anyURI(concat($target,"/data/ads-cache.xml")), "rw-rw-rw-")
return true()
