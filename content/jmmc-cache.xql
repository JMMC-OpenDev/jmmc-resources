xquery version "3.0";

(:~
 : This modules contains simple helpers to manage a cache of items based on a
 : node in the database.
 : 
 : Any content can be associated with a key and later queried and retrieved
 : with the same key. Duplicated keys are allowed.
 : 
 : The entries are serialized as children of a node in the database. The caller
 : of the functions below have to have the appropriate rights on parent
 : document.
 : 
 : The functions can be locally aliased with partial function application to
 : conceal the cache node.
 : 
 : @see http://atomic.exist-db.org/blogs/eXist/HoF
 :)
module namespace jmmc-cache="http://exist.jmmc.fr/jmmc-resources/cache";

(:~
 : Add a record to the given cache for the specified key.
 :
 : @param $cache the cache node
 : @param $key   the key to identify the entry
 : @param $data  the record to add to the cache
 : @return the given data added to the cache
 :)
declare function jmmc-cache:insert($cache as node(), $key as xs:string, $data as item()*) as item()*{
    let $update := update insert <cached key="{ $key }" date="{current-dateTime()}">{ $data }</cached> into $cache
    return $data
};

(:~
 : Test whether the given cache has an entry for a key.
 : 
 : @param $cache the cache node
 : @param $key   the key to search for in cache entries
 : @return true if found, false otherwise
 :)
declare function jmmc-cache:contains($cache as node(), $key as xs:string) as xs:boolean {
    exists($cache/cached[@key=$key])
};

(:~
 : Return the records associated to a key in the given cache.
 : 
 : The returned sequence of values is ordered by the date and time the matching
 : entries have been inserted (latest entry first).
 : 
 : @note
 : Use jmmc-cache:contains() to distinguish an entry with en empty contents
 : from the case where there is no entry with this key.
 : 
 : @param $cache the cache node
 : @param $key   the key to search for in cache entries
 : @return a sequence of records or empty if nothing in cache
 :)
declare function jmmc-cache:get($cache as node(), $key as xs:string) as item()* {
    for $cached in $cache/cached[@key=$key]
    order by xs:dateTime($cached/@date) descending
    return $cached/*
};

(:~
 : Return the keys associated to a record in the given cache.
 : 
 : @param $cache the cache node
 : @return the keys of cached records or empty if nothing in cache
 :)
declare function jmmc-cache:keys($cache as node()) as xs:string* {
    distinct-values(data($cache/cached/@key))
};

(:~
 : Remove all cached entries from the given cache.
 : 
 : @param $cache the cache node
 : @return empty
 :)
declare function jmmc-cache:flush($cache as node()) {
    for $cached in $cache/cached
    return update delete $cached
};
