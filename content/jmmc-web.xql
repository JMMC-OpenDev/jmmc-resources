xquery version "3.0";

(:~
 : This modules contains common elements to synchronize content with the main JMMC web site or provide util functions web related.
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
        <img alt="logo" height="30" src="//www.jmmc.fr/sites/jmmc.fr/IMG/siteon0.png"/>
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
    <a href="#" class="dropdown-toggle" style="padding:12px;" data-toggle="dropdown"><img height="30" src="//www.jmmc.fr/sites/jmmc.fr/IMG/siteon0.png"/>&#160;<span class="caret"></span></a>
    <ul class="dropdown-menu">        
    {$lis}
    </ul>
    </li>
let $store := xmldb:store($jmmc-web:menu-col-path, $jmmc-web:menu-doc-name, $ret)
return $ret
};

(:~
 : Provide a javascript encoded array to fill an html attribute that can display an email after client side decoding.
 : TODO move into jmmc-auth
 :)
declare function jmmc-web:get-encoded-email-array($email as xs:string) as xs:string
{
  let $pre := substring-before($email,"@")
  let $pre := translate($pre, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm")

  let $post := substring-after($email,"@")
  let $post := translate($post, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm")
  let $post := tokenize( $post , "\.")
  let $post := reverse( $post )
  let $mailto := translate("mailto:", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm")
  let $mailto := $mailto ! string-to-codepoints(.) ! codepoints-to-string(.)

  return "[[&apos;"||string-join($mailto, "&apos;, &apos;")||"&apos;],[&apos;"||$pre||"&apos;],[&apos;"||string-join($post, "&apos;, &apos;")|| "&apos;]]"
};

(:~
 : Provide a javascript decoder code.
 : TODO move into jmmc-auth
 :)
declare function jmmc-web:get-encoded-email-decoder() as xs:string {
    <script>
    <![CDATA[
    // connect the contact links
    $('a[data-contarr]').on('click', function (e){
        var array = eval($(this).data('contarr'))
        var str = array[0].join('')+array[1]+'@'+array[2].reverse().join('.');
        location.href=str.rot13();
        return false;
    });
    ]]>
    </script>

};

