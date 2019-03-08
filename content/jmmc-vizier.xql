xquery version "3.0";

(:~
 : This modules contains functions to extract data from VizieR catalogs.
 : 
 : Through a rough parser, it is possible to retrieve elements from the
 : description file, aka ReadMe file, of a particular catalog (see Standards
 : for Astronomical Catalogues, Version 2.0 (February 2000),
 : http://cds.u-strasbg.fr/doc/catstd.htx)
 : 
 : It is also possible to retrieve the list of URL for OIFITS in the catalog
 : files.
 : 
 : It can also query VizieR though its TAP interface in sync mode.
 : 
 :)
module namespace jmmc-vizier="http://exist.jmmc.fr/jmmc-resources/vizier";

import module namespace http-client="http://exist-db.org/xquery/httpclient";
import module namespace ft-client="http://expath.org/ns/ft-client";

declare namespace votable="http://www.ivoa.net/xml/VOTable/v1.3";
declare namespace http="http://expath.org/ns/http-client";

(: The base URL for accessing catalog ReadMe files at VizieR :)
declare variable $jmmc-vizier:VIZIER_CATALOGS := 'http://cdsarc.u-strasbg.fr/vizier/ftp/cats/';

(: The VizieR TAP endpoint :)
declare variable $jmmc-vizier:TAP-SYNC := "http://tapvizier.u-strasbg.fr/TAPVizieR/tap/sync";

(: Value of current votable namespace :)
declare variable $jmmc-vizier:vot-ns := namespace-uri(element votable:dummy {});



(:~
 : Retrieve and read the description file of the named catalog.
 : 
 : It gets contents of the ReadMe file from VizieR.
 : 
 : @param $name a catalog identifier
 : @return the text of the catalog description file
 : @error catalog description not found
 :)
declare function jmmc-vizier:catalog($name as xs:string) as xs:string? {
    let $readme-url := resolve-uri($name || '/ReadMe', $jmmc-vizier:VIZIER_CATALOGS)
    let $data := httpclient:get($readme-url, false(), <headers/>)
    return if ($data/@statusCode = 200) then
        util:base64-decode($data/httpclient:body/text())
    else 
        (
        error(xs:QName('jmmc-vizier:error'), 'Catalog description file not found'),
        util:log("error",'Catalog description file not found at '||$readme-url)
        )
};

(:~
 : Extract the title from a catalog description.
 : 
 : It returns the abbreviated title from the first line of the description
 : next to the catalog designation.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return the title of the catalog
 :)
declare function jmmc-vizier:catalog-title($readme as xs:string) as xs:string {
    normalize-space(substring-after(tokenize($readme, '\n')[1], ' '))
};

(:~
 : Extract the bibcodes from a catalog description.
 : 
 : It returns the bibcodes for the first section.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return a sequence of bibcode attached to the catalog
 :)
declare function jmmc-vizier:catalog-bibcodes($readme as xs:string) as xs:string* {
    (: bibcodes at beginning of indented line, '='-prefixed :)
    let $seq := subsequence(tokenize($readme, '^ +=', 'm'), 2)
    for $s in $seq
    (: strip prefix :)
    let $bibcode := substring($s, 1, 19)
    (: TODO better bibcode validator :)
    return if (matches($bibcode, '^[0-9a-zA-Z&amp;\.]*$')) then $bibcode else ()
};

(:~
 : Return the contents of a given section in a catalog description.
 : 
 : Note that it only supports sections with indented contents (not 'File
 : Summary' and 'Byte-by-byte Description' sections) and the text returned
 : is unindented.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @param $section a section name
 : @return the contents of the requested section if found.
 :)
declare %private function jmmc-vizier:catalog-section($readme as xs:string, $section as xs:string) as xs:string {
    (: find the section header in the description :)
    let $chunk := tokenize($readme, '^' || $section || '.*\n', 'mi')[2]
    (: return any indented text following the header :)
    return replace(tokenize($chunk, '^[^\s]', 'm')[1], '^ +', '', 'm')
};

(:~
 : Extract the abstract from a catalog description.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return the abstract of the catalog
 :)
declare function jmmc-vizier:catalog-abstract($readme as xs:string) as xs:string {
    jmmc-vizier:catalog-section($readme, 'Abstract')
};

(:~
 : Extract the description from a catalog description.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return the description of the catalog
 :)
declare function jmmc-vizier:catalog-description($readme as xs:string) as xs:string {
    jmmc-vizier:catalog-section($readme, 'Description')
};

(:~
 : Extract the date of last modification from a catalog description.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return the date of last modification
 :)
declare function jmmc-vizier:catalog-date($readme as xs:string) as xs:string {
    (: get last line of description :)
    let $last-line := tokenize($readme, '\n')[starts-with(., '(End)')]
    (: skip (End) marker, keep right flushed text :)
    return tokenize($last-line, '\s+')[last()]
};

(:~
 : Extract the name of the creator of the catalog from a catalog description.
 : 
 : @param $readme a catalog description (contents of the ReadMe)
 : @return the name of the catalog creator
 :)
declare function jmmc-vizier:catalog-creator($readme as xs:string) as xs:string {
    (: search for first indented chunk of text :)
    (: it follows the header and full title and its lists the author names :)
    let $chunk := tokenize($readme, '^\s+', 'm')
    (: keep the first author as creator :)
    return normalize-space(tokenize($chunk[2], ',')[1])
};

(:~
 : Walk the file system tree descending from the given path and calling a
 : function for selecting files.
 : 
 : It starts at the given path and recursively search deeper in the
 : subdirectories.
 : 
 : The function takes the current path and the name of the file as parameters.
 : 
 : The predicate is called on every file encountered. If it evaluates to true,
 : the full path for the file is added to the return value. Otherwise the file
 : is ignored.
 : 
 : @param $connection the connection handle
 : @param $path path to start search from
 : @param $func predicate function applied to each file
 : @return a list of paths for files satisfying predicate
 :)
declare %private function jmmc-vizier:ftw($connection as xs:long, $path as xs:string, $func as function(*)) as xs:string* {
    let $path := if (ends-with($path, '/')) then $path else $path || '/'
    
    let $resources := ft-client:list-resources($connection, $path)
    let $dir-paths := for $d in $resources//ft-client:resource[@type='directory']/@name return $path || $d

    return (
        for $r in $resources//ft-client:resource return if ($func($path, $r)) then $path || $r/@name else (),
        for $path in $dir-paths return jmmc-vizier:ftw($connection, $path, $func)
    )
};

(: The base FTP url for accessing catalog files :)
declare variable $jmmc-vizier:VIZIER_CATALOGS_FTP := xs:anyURI('ftp://anonymous:@cdsarc.u-strasbg.fr/pub/cats');

(:~
 : Get the URLs of OIFITS files attached to a VizieR catalog.
 : 
 : It browses the FTP tree of directory attached to the catalog, searching
 : for OIFITS files.
 : 
 : @param $name a VizieR catalog identifier
 : @return a sequence of HTTP URL of OIFITS files of the catalog
 :)
declare function jmmc-vizier:catalog-fits($name as xs:string) as xs:string* {
    (: open a FTP connection :)
    let $connection := ft-client:connect($jmmc-vizier:VIZIER_CATALOGS_FTP)

    (: very simple filter for identifying OIFITS candidate files :)
    let $fits := function($path, $resource) as xs:boolean { boolean($resource[./@type='file' and ./ends-with(@name, 'fits')]) }
    (: search the directory tree of the catalog for matching files :)
    let $files := jmmc-vizier:ftw($connection, '/pub/cats/' || $name, $fits)
    (: build HTTP URLs from paths:)
    let $files :=
        for $f in $files 
        return resolve-uri(substring-after($f, '/pub/'), 'http://cdsarc.u-strasbg.fr/vizier/ftp/')

    let $connection := ft-client:disconnect($connection)
    return $files
};

(:~
 : Execute an ADQL query against a TAP service.
 :
 : Warning: (comment was for simbad) CDS set a query limit for the TAP service of max 6 requests per second. 
 : 403 error code is returned when limit is encountered.
 :
 : @param $uri   the URI of a TAP sync resource
 : @param $query the ADQL query to execute
 : @return a VOTable with results for the query
 : @error service unavailable, bad response
 :)
declare function jmmc-vizier:tap-adql-query($uri as xs:string, $query as xs:string) as node() {
    let $uri := $uri || '?' || string-join((
        'REQUEST=doQuery',
        'LANG=ADQL',
        'FORMAT=votable', 
        'QUERY=' || encode-for-uri($query)), '&amp;')
    let $response        := http:send-request(<http:request method="GET" href="{$uri}"/>)
    let $response-status := $response[1]/@status 
    
    return if ($response-status != 200) then
        error(xs:QName('jmmc-vizier:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='|| $query ||', response='|| serialize($response) ||')', $query)
    else if (count($response[1]/http:body) != 1) then
        error(xs:QName('jmmc-vizier:TAP'), 'Bad content returned')
    else
        let $body := $response[2]
        return if ($body instance of node()) then $body else util:parse($body)
};


