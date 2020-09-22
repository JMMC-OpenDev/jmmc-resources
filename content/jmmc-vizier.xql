xquery version "3.1";

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

import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

import module namespace ft-client="http://expath.org/ns/ft-client";

declare namespace votable="http://www.ivoa.net/xml/VOTable/v1.3";

(: The base URL for accessing catalog descriptions at VizieR ( default is json else ?format=html&tex=true) :)
declare variable $jmmc-vizier:VIZIER_CATALOGS := 'http://cdsarc.u-strasbg.fr/viz-bin/ReadMe/';

(: The VizieR TAP endpoint :)
declare variable $jmmc-vizier:TAP-SYNC := "http://tapvizier.u-strasbg.fr/TAPVizieR/tap/sync";

(: Value of current votable namespace :)
declare variable $jmmc-vizier:vot-ns := namespace-uri(element votable:dummy {});

(: Cache name for catalog descriptions :)
declare variable $jmmc-vizier:cache-name := "jmmc-resources/vizier/catalogs";

(:~
 : Retrieve and read the description of the named catalog.
 : 
 : It gets contents of the ReadMe like descriptor from VizieR from a json data source.

 : @param $name a catalog identifier
 : @return the data structure
 : @error catalog description not found
 :)
declare function jmmc-vizier:catalog($name as xs:string) as map(*)? {
    let $name := normalize-space($name)
    let $desc-url := resolve-uri($name, $jmmc-vizier:VIZIER_CATALOGS)
    let $cache := cache:get($jmmc-vizier:cache-name, $name)
    return 
        if(exists($cache)) then 
            $cache
        else
            let $data := json-doc($desc-url)
            return 
                if (exists($data)) then
                    let $cacheit := cache:put($jmmc-vizier:cache-name, $name, $data)
                    return $data
                else 
                    (
                        error(xs:QName('jmmc-vizier:error'), 'Catalog description not foundat at '||$desc-url),
                        util:log("error",'Catalog description file not found at '||$desc-url)
                    )
};


(:~
 : Extract the title from a catalog description.
 : 
 : It returns the abbreviated title from the first line of the description
 : next to the catalog designation.
 : 
 : @param $name a catalog identifier
 : @return the title of the catalog
 :)
declare function jmmc-vizier:catalog-title($name as xs:string) as xs:string {
    let $desc := jmmc-vizier:catalog($name)
    return 
        ($desc("title"), $desc("title_cds"))[1]
};

(:~
 : Extract the bibcodes from a catalog description.
 : 
 : It returns the bibcodes for the first section.
 : 
 : @param $name a catalog identifier
 : @return a sequence of bibcode attached to the catalog
 :)
declare function jmmc-vizier:catalog-bibcodes($name as xs:string) as xs:string* {
    let $desc := jmmc-vizier:catalog($name)
    return 
        array:flatten($desc("bibcode"))
};

(:~
 : Extract the abstract from a catalog description.
 : 
 : @param $name a catalog identifier
 : @return the abstract of the catalog
 :)
declare function jmmc-vizier:catalog-abstract($name as xs:string) as xs:string {
    let $desc := jmmc-vizier:catalog($name)
    return
        string-join(data($desc?abstract), "&#10;")
  
};

(:~
 : Extract the description from a catalog description.
 : 
 : @param $name a catalog identifier
 : @return the description of the catalog
 :)
declare function jmmc-vizier:catalog-description($name as xs:string) as xs:string {
    let $desc := jmmc-vizier:catalog($name)
    return 
        string-join(data($desc?description), "&#10;")
};

(:~
 : Extract the date of last modification from a catalog description.
 : 
 : @param $name a catalog identifier
 : @return the date of last modification
 :)
declare function jmmc-vizier:catalog-date($name as xs:string) as xs:string {
    let $desc := jmmc-vizier:catalog($name)
    return 
        $desc("last_update")
};

(:~
 : Extract the name of the creator of the catalog from a catalog description.
 : 
 : @param $name a catalog identifier
 : @return the name of the catalog creator
 :)
declare function jmmc-vizier:catalog-creator($name as xs:string) as xs:string {
    let $desc := jmmc-vizier:catalog($name)
    return 
        $desc("first_author")
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
    let $name := normalize-space($name)
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
    let $response        := hc:send-request(<hc:request method="GET" href="{$uri}"/>)
    let $response-status := $response[1]/@status 
    
    return if ($response-status != 200) then
        error(xs:QName('jmmc-vizier:TAP'), 'Failed to retrieve data (HTTP_STATUS='|| $response-status ||', query='|| $query ||', response='|| serialize($response) ||')', $query)
    else if (count($response[1]/hc:body) != 1) then
        error(xs:QName('jmmc-vizier:TAP'), 'Bad content returned')
    else
        let $body := $response[2]
        return if ($body instance of node()) then $body else fn:parse-xml($body)
};


declare
    %test:assertTrue
(:function jmmc-vizier:test-module( ) as xs:boolean {:)
function jmmc-vizier:test-module( ) {
    let $name := " J/A+A/597/A137" (: leave blank to ensure cleanup by subcode :)
(:    let $cat := jmmc-vizier:catalog($name):)
    let $abstract := jmmc-vizier:catalog-abstract($name)
    let $bibcodes := jmmc-vizier:catalog-bibcodes($name)
    let $creator := jmmc-vizier:catalog-creator($name)
    let $date := jmmc-vizier:catalog-date($name)
    let $description := jmmc-vizier:catalog-description($name)
    let $title := jmmc-vizier:catalog-title($name)
    let $fits := jmmc-vizier:catalog-fits($name)
    
    let $expected := (
        normalize-space("The photospheric radius is one of the fundamental parameters governing the radiative equilibrium of a star. We report new observations of the nearest solar-type stars Alpha Centauri A (G2V) and B (K1V) with the VLTI/PIONIER optical interferometer. The combination of four configurations of the VLTI enable us to measure simultaneously the limb darkened angular diameter thetaLD and the limb darkening parameters of the two solar-type stars in the near-infrared H band (lambda=1.65um). We obtain photospheric angular diameters of {theta}_LD(A)_=8.502+/-0.038mas (0.43%) and {theta}_LD(B)_=5.999+/-0.025mas (0.42%), through the adjustment of a power law limb darkening model. We find H band power law exponents of {alpha}_(A)_=0.1404+/-0.0050 (3.6%) and {alpha}_(B)_=0.1545+/-0.0044 (2.8%), which closely bracket the observed solar value (alpha_{sun}_=0.15027). Combined with the parallax pi=747.17+/-0.61mas determined by Kervella et al. (2016), we derive linear radii of R_A_=1.2234+/-0.0053R_{sun}_ (0.43%) and R_B_=0.8632+/-0.0037R_{sun}_ (0.43%). The power law exponents that we derive for the two stars indicate a significantly weaker limb darkening than predicted by both 1D and 3D stellar atmosphere models. As this discrepancy is also observed on the near-infrared limb darkening profile of the Sun, an improvement of the calibration of stellar atmosphere models is clearly needed. The reported PIONIER visibility measurements of Alpha Cen A and B provide a robust basis to validate the future evolutions of these models."),
        "2017A&amp;A...597A.137K",
        "Kervella P.",
        "23-Jan-2017",
        normalize-space("The files contain all the PIONIER calibrated interferometric data obtained on Alpha Centauri A and B, as well as on the dimensional calibrator HD 123999. The data files follow the OIFITS standard of optical interferometry as defined by Pauls et al. (2005PASP..117.1255P). "),
        "HD 123999 and Alpha Cen A and B OIFITS files",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160221_HD123999.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160229_HD123999.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160301_HD123999.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160523_AlphaCenA_1.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160523_AlphaCenA_2.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160523_AlphaCenB.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160527_AlphaCenA.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160527_AlphaCenB.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160529_AlphaCenA.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160529_AlphaCenB.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160530_AlphaCenA.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160530_AlphaCenB.fits",
        "http://cdsarc.u-strasbg.fr/vizier/ftp/cats/J/A+A/597/A137/oifits/20160530_HD123999.fits"
    )
        
    let $result := ( normalize-space($abstract), $bibcodes, $creator, $date, normalize-space($description), $title, $fits )
    let $failures := for-each-pair( $expected, $result, function ($e1, $e2){ if ($e1 = $e2) then () else "expected: "||$e1|| " , was: "||$e2} )
    return 
        if(empty($failures)) then true() else $failures
};


