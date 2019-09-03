xquery version "3.0";

(:~
 : This module contains a set of functions for templating in the About page
 : of the application.
 : 
 : It makes use of the changelog element from the deployment descriptor of the
 : application (repo.xml).
 : to use it just include following fragment:
 : <h2>ChangeLog</h2>
 :   <div data-template="jmmc-about:changelog">
 :       Current version: <span data-template="jmmc-about:version"/>
 :       <div data-template="templates:each" data-template-from="changes" data-template-to="change">
 :           <div>
 :               <hr/>
 :               <div>
 :                   <b>Version <span data-template="jmmc-about:change-version"/>
 :                   </b>
 :               </div>
 :               <div data-template="jmmc-about:change"/>
 :           </div>
 :       </div>
 :   </div>
 : 
 : It is also necessary to set-up the templating framework of the application
 : to look for the functions of this module. To do so, add the following line
 : to the 'view.xql' of the application:
 : import module namespace jmmc-about="http://exist.jmmc.fr/jmmc-resources/about";
 :)

module namespace jmmc-about="http://exist.jmmc.fr/jmmc-resources/about";

import module namespace templates="http://exist-db.org/xquery/templates";


(:~
 : Get the list of changes of the application into "repo.xml" doc from given app-root.
 : 
 : @param $app-root
 : @return a map with changes to be added to current $model map.
 :)
declare function jmmc-about:changelog($app-root as xs:string) {    
    let $changes := doc($app-root || '/repo.xml')//change
    return  $changes 
};

(:~
 : Fill the current model for subsequent uses by other templating functions with:
 : - changes elements
 : - deployed date
 : - status 
 : - stable entry if repo.xml status element is stable
 : 
 : It makes use of the current $model map to get the application path from its "app-root" key.
 : 
 : @param $node
 : @param $model
 : @return a map with following keys : "changes", "status", "deployed" and "stable" depending on the repo.xml status element.
 :)
declare
    %templates:wrap
function jmmc-about:changelog($node as node(), $model as map(*)) as map(*) {
    let $app-root := $model($templates:CONFIGURATION)($templates:CONFIG_APP_ROOT)
    let $repo := doc($app-root || '/repo.xml')
    let $deployed := ($repo//*:deployed/text())[1]
    let $status := $repo//*:status/text()
    let $map := map { "changes" : jmmc-about:changelog($app-root), "deployed" :  $deployed, "status" : $status}
    return
        if ($status="stable") then
                map:new(($map, map:entry("stable", true())))
            else
                $map
};

(:~
 : Return the current version number of the application.
 : 
 : It makes use of the current $model map to get the list of changes.
 : 
 : @param $node
 : @param $model
 : @return the current version of the application as string.
 :)
declare 
    %templates:wrap
function jmmc-about:version($node as node(), $model as map(*)) as xs:string? {
    let $changes := $model("changes")
    (: Note: turn version into number for comparison :)
    (: force version number format to all numbers and single dot and XX.9 after XX.10 :)
    let $version := $changes[@version=max($changes/@version)]/@version
    return if($version) then $version else "not provided"
};
(:~
 : Return the current status of the application.
 : 
 : It makes use of the current $model map to get the list of changes.
 : 
 : @param $node
 : @param $model
 : @return the current status of the application as string : alpha, beta or stable.
 :)
declare 
    %templates:wrap
function jmmc-about:status($node as node(), $model as map(*)) as xs:string? {
    let $status := $model("status")
    return if($status) then $status else ()
};


(:~
 : Return the deployement date of the application.
 : 
 : It makes use of the current $model map to get the list of changes.
 : 
 : @param $node
 : @param $model
 : @return the current deployement date of the application as string.
 :)
declare 
    %templates:wrap
function jmmc-about:deployed($node as node(), $model as map(*)) as xs:string? {
    let $d := $model("deployed")
    return if($d) then $d else "not provided"
};

(:~
 : Return the current version number of the application as an attribute.
 : 
 : It does not rely on model like jmmc-about:version above.
 : 
 : @param $node
 : @param $model
 : @param $attrname the name wanted forthe returned attribute
 : @return an attribute of given name with value equal to application version.
 :)
declare
    %templates:wrap
function jmmc-about:version-as-attribute($node as node(), $model as map(*), $attrname as xs:string) as attribute() {    
    let $changes := $model("changes")
    return attribute { $attrname }  { $changes[@version=max($changes/@version)]/@version }
};

(:~
 : Return the changelog associated with a verion.
 : 
 : It makes use of the current $model map to get the change.
 : 
 : @param $node
 : @param $model
 : @return a HTML fragment with changelog.
 :)
declare function jmmc-about:change($node as node(), $model as map(*)) as node()* {
    (: change is a HTML fragment in repo.xml, return children :)
    $model("change")/*
};

(:~
 : Return the version number of a change in the model.
 : 
 : Version number is an attribute on the element associated to the 'change' key
 : of the model.
 : 
 : @param $node
 : @param $model
 : @return the version number as a string 
 :)
declare function jmmc-about:change-version($node as node(), $model as map(*)) as xs:string {
    data($model("change")/@version)
};
