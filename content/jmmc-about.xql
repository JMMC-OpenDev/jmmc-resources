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
 : Put the list of changes of the application into the current model for
 : subsequent uses by other templating functions.
 : 
 : It makes use of the current $model map to get the application path from its "app-root" key.
 : 
 : @param $node
 : @param $model
 : @return a map with changes to be added to current $model map.
 :)
declare
    %templates:wrap
function jmmc-about:changelog($node as node(), $model as map(*)) as map(*) {
    let $app-root := $model($templates:CONFIGURATION)($templates:CONFIG_APP_ROOT)
    return map:new(($model,map { "changes" := jmmc-about:changelog($app-root) }))
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
     let $app-root := $model("app-root")
    let $changes := doc($app-root || '/repo.xml')//change
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

declare function jmmc-about:change-version($node as node(), $model as map(*)) as xs:string {
    data($model("change")/@version)
};

