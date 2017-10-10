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
  <li class="dropdown">
    <a href="#" class="dropdown-toggle" style="padding:12px;" data-toggle="dropdown">
        <img height="30" src="//jmmc.obs.ujf-grenoble.fr/images/jmmc_large.jpg"/> <span class="caret"/>
    </a>
    <ul class="dropdown-menu">
        <li>
            <a href="http://www.jmmc.fr//about_jmmc.htm">Who are we ?</a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//jmm.htm">Who was JMM ?</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//jmmc_partners.htm">Partners</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//jmmc_structure.htm">Structure</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//jmmc_groups.htm">Working Groups</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//training.htm">Training</a>
            <ul/>
        </li>
        <li>
            <a href="http://www.jmmc.fr//proposals.htm">Proposal Preparation</a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//aspro_page.htm">ASPRO</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//getstar.htm">GetStar</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//searchcal_page.htm">SearchCal</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//eso_proposals.htm">VLTI Proposals</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//data_processing.htm">Data Processing</a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//data_processing_amber.htm">AMBER</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//data_processing_pionier.htm">PIONIER</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//oifitsexplorer_page.htm">OIFits Explorer</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//oival_page.htm">Oifits Validator</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//data_analysis.htm">Data Analysis</a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//litpro_page.htm">LITpro</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//oimaging.htm">OImaging</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//vo_resources.htm">
          Databases
          </a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//badcal">BadCal</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//catalogue_calex.htm">CalEx</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//oidb.htm">OiDB</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//catalogue_jmdc.htm">JMDC</a>
                </li>
                <li>
                    <a href="http://www.jmmc.fr//catalogue_jsdc.htm">JSDC</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//vo_resources.htm">
          VO tool
          </a>
            <ul>
                <li>
                    <a href="http://www.jmmc.fr//applauncher_page.htm">AppLauncher</a>
                </li>
            </ul>
        </li>
        <li>
            <a href="http://www.jmmc.fr//support.htm">User Support</a>
            <ul/>
        </li>
        <li>
            <a href="http://www.jmmc.fr//database_olbin_publications.htm">Publications</a>
            <ul/>
        </li>
        <li>
            <a href="http://www.jmmc.fr//job_offers.htm">Job Offers</a>
            <ul/>
        </li>
    </ul>
</li>

};

(:~
 : Compute the left menu navbar content for inclusion in bootstrap and store in a local document for get-jmmc-nav-bar function.
 : This will request the main www.jmmc.fr web page on each call.  Prefer to get the 
 : copied/paste content using get-jmmc-nav-bar
 : @return a li element to include in bootstrap navbar
 : NOT TESTED PROPERLY
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

