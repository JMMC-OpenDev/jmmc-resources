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


(: remove public access on exide even if this is better to be not reachable from the web... :)
(:let $avoid_public_exide := update replace doc("/db/apps/eXide/configuration.xml")/configuration/restrictions/@guest  with "no" :)

let $dep := repo:install-and-deploy("http://expath.org/ns/ft-client", "1.2.0", "http://demo.exist-db.org/exist/apps/public-repo/modules/find.xql") 

return true()
