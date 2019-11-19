xquery version "3.0";

(:~
 : This modules contains common elements to synchronize content with the main JMMC web site.
 :)
module namespace jmmc-web="http://exist.jmmc.fr/jmmc-resources/web";


declare namespace xhtml="http://www.w3.org/1999/xhtml";

declare variable $jmmc-web:menu-col-path := "/db/apps/jmmc-resources/data/";
declare variable $jmmc-web:menu-doc-name := "menu.xml";

(:~
 : Return the left menu navbar content for inclusion in bootstrap.
 : try first content of /db/apps/jmmc-ressources/data/menu.xml then constant xml fragment
 : @return a li element to include in bootstrap navbar
 :)
declare function jmmc-web:navbar-li($node as node(), $model as map(*)) as node() {
 let $menu-doc := doc($jmmc-web:menu-col-path || $jmmc-web:menu-doc-name) 
 return if ($menu-doc) then $menu-doc
 else
  <li >
    <a href="//www.jmmc.fr">
        <img alt="logo" height="30" src="//www.jmmc.fr/images/jmmc_large.jpg"/>
    </a>
  </li>

};

(:~
 : Compute the left menu navbar content for inclusion in bootstrap and store in a local document for get-jmmc-nav-bar function.
 : This will request the main www.jmmc.fr web page on each call.  Prefer to get the 
 : copied/paste content using get-jmmc-nav-bar
 : @return a li element to include in bootstrap navbar
 : NOT TESTED PROPERLY and no more compatible with SPIP version to be release before end of 2019
 :)
declare function jmmc-web:compute-navbar() as node() {
let $div:=doc("http://www.jmmc.fr/")//xhtml:div[@id="sectionLinks"]
let $lis:= for $l1 in $div/xhtml:li let $a := $l1/xhtml:a let $href := if(contains($a/@href,"//"))  then $a/@href else "http://www.jmmc.fr/"||$a/@href return <li><a href="{$href}">{data($a)}</a>
            <ul>
                {
                    for $a in $l1/xhtml:div/xhtml:a 
                    let $href := if(contains($a/@href,"//"))  then $a/@href else "http://www.jmmc.fr/"||$a/@href
                    return 
                    <li><a href="{$href}">{data($a)}</a></li>
                }
            </ul>
        </li>
        
let $ret := <li class="dropdown">
    <a href="#" class="dropdown-toggle" style="padding:12px;" data-toggle="dropdown"><img height="30" src="//jmmc.obs.ujf-grenoble.fr/images/jmmc_large.jpg"/>&#160;<span class="caret"></span></a>
    <ul class="dropdown-menu">        
    {$lis}
    </ul>
    </li>
let $store := xmldb:store($jmmc-web:menu-col-path, $jmmc-web:menu-doc-name, $ret)
return $ret
};

