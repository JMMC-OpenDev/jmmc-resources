xquery version "3.0";

(:~
 : This modules contains simple helpers to manage a cache of items based on a
 : document in the database.
 : 
 : Any content can be associated with a key and later queried and retrieved
 : with the same key.
 : 
 : The entries are serialized to a document in the database. The caller of the
 : functions below have to have the appropriate rights on this document.
 : 
 : The functions can be locally aliased with partial function application to
 : conceal the cache document.
 : 
 : @see http://atomic.exist-db.org/blogs/eXist/HoF
 :)
module namespace jmmc-cache="http://exist.jmmc.fr/jmmc-resources/cache";

(:~
 : Add a record to the given cache for the specified key.
 : 
 : @param $cache the cache document
 : @param $key   the key to identify the entry
 : @param $data  the record to add to the cache
 : @return empty
 :)
declare function jmmc-cache:insert($cache as node(), $key as xs:string, $data as item()*) {
    update insert <cached key="{ $key }">{ $data }</cached> into $cache/*
};

(:~
 : Test whether the given cache has an entry for a key.
 : 
 : @param $cache the cache document
 : @param $key   the key to search for in cache entries
 : @return true if found, false otherwise
 :)
declare function jmmc-cache:contains($cache as node(), $key as xs:string) as xs:boolean {
    exists($cache//cached[@key=$key])
};

(:~
 : Return the record associated to a key in the given cache.
 : 
 : @param $cache the cache document
 : @param $key   the key to search for in cache entries
 : @return the record previously cached or empty if nothing in cache
 :)
declare function jmmc-cache:get($cache as node(), $key as xs:string) as item()* {
    head($cache//cached[@key=$key])/*
};

(:~
 : Remove all cached entries from the given cache.
 : 
 : @param $cache the cache document
 : @return empty
 :)
declare function jmmc-cache:flush($cache as node()) {
    for $cached in $cache//cached
    return update delete $cached
};

(:~
 : Delete the given cache.
 : 
 : @param $cache the cache document
 : @return empty
 :)
declare function jmmc-cache:destroy($cache as node()) {
    let $uri := tokenize(document-uri($cache), '/')
    let $collection := string-join($uri[position()!=last()], '/')
    let $resource   := $uri[position()=last()]
    return try {
        xmldb:remove($collection, $resource)
    } catch * {
        ()
    }
};
