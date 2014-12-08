xquery version "3.0";

(:~
 : This modules contains simple helpers to manage a cache of items based on a
 : document in the database.
 : 
 : Any content can be associated with a key and later queried and retrieved
 : with the same key. Duplicated keys are allowed.
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
 : @return the given data added to the cache
 :)
declare function jmmc-cache:insert($cache as node(), $key as xs:string, $data as item()*) as item()*{
    let $update := update insert <cached key="{ $key }" date="{current-dateTime()}">{ $data }</cached> into $cache/*
    return $data
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
 : Return the records associated to a key in the given cache.
 : 
 : @note
 : Use jmmc-cache:contains() to distinguish an entry with en empty contents
 : from the case where there is no entry with this key.
 : 
 : @param $cache the cache document
 : @param $key   the key to search for in cache entries
 : @return a sequence of records or empty if nothing in cache
 :)
declare function jmmc-cache:get($cache as node(), $key as xs:string) as item()* {
    $cache//cached[@key=$key]/*
};

(:~
 : Return the records associated to a list of keys in the given cache.
 : 
 : @param $cache the cache document
 : @param $keys   the keys to search for in cache entries
 : @return the records previously cached or empty if nothing in cache
 :)
declare function jmmc-cache:get($cache as node(), $keys as xs:string*) as item()* {
    $cache//cached[@key=$keys]/*
};

(:~
 : Return the keys associated to a record in the given cache.
 : Warning: duplicated keys may appear waiting insert function fix (see TODO)
 : @param $cache the cache document
 : @return the keys of cached records or empty if nothing in cache
 :)
declare function jmmc-cache:keys($cache as node()) as xs:string* {
    data($cache//cached/@key)
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
