xquery version "3.0";


(:~
 : Utility functions to interact with user's jmmc authentication system.
 :)
module namespace jmmc-auth="http://exist.jmmc.fr/jmmc-resources/auth";


declare variable $jmmc-auth:serviceAccesspointUrl := xs:anyURI('https://jmmc.obs.ujf-grenoble.fr/account/manage.php');

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:getObfuscatedEmail($email as xs:string) as xs:string
{
    jmmc-auth:get-obfuscated-email($email)
};

(: Improve this function to get whole email for admin users :)
declare function jmmc-auth:get-obfuscated-email($email as xs:string) as xs:string
{
  substring-before($email,"@")||"@..."  
};


(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:checkPassword($email, $password)
{
    jmmc-auth:check-password($email, $password)
};

declare function jmmc-auth:check-password($email, $password)
{
    let $fields :=
                   <httpclient:fields>
        <httpclient:field name="email" value="{ $email }" type="string"/>
        <httpclient:field name="password" value="{ $password }" type="string"/>
        <httpclient:field name="action" value="checkPassword" type="string"/>
    </httpclient:fields>
    let $postResponse := httpclient:post-form($jmmc-auth:serviceAccesspointUrl, $fields, false(), ())
    (: true or false tag are embedded near the user message SUCCEEDED/FAILED :) return
        exists($postResponse//true)
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:getInfo($email)
{
    jmmc-auth:get-info($email)
};

declare function jmmc-auth:get-info($email)
{
    if($email) then
    let $fields :=
        <httpclient:fields>
        <httpclient:field name="email" value="{ $email }" type="string"/>
        <httpclient:field name="action" value="getInfo" type="string"/>
        </httpclient:fields>
        let $postResponse := httpclient:post-form($jmmc-auth:serviceAccesspointUrl, $fields, false(), ())
        let $resp := $postResponse//response[1]
        return
            <author><email>{ $email }</email>{ $resp/* }</author>
    else
        ()
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:getInfo()
{
    jmmc-auth:get-info()
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:get-info()
{
    jmmc-auth:get-info(session:get-attribute("email"))
};

declare function jmmc-auth:check-credential($email as xs:string, $crendential as xs:string) as xs:boolean
{
    let $info := jmmc-auth:get-info($email)
    return exists($info//credential/*[lower-case(name())=lower-case($crendential)])
};


declare function jmmc-auth:check-credential($crendential as xs:string) as xs:boolean
{
    let $info := jmmc-auth:get-info()
    return exists($info//credential/*[lower-case(name())=lower-case($crendential)])
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:isLogged($email)
{
    jmmc-auth:is-logged($email)
};
 

declare function jmmc-auth:is-logged($email)
{
    let $attr := session:get-attribute("email") = $email
    (: if($attr) :)
    return $attr
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:isLogged()
{
     jmmc-auth:is-logged()
};


declare function jmmc-auth:is-logged()
{
    session:get-attribute("email")
};

declare function jmmc-auth:login($email, $password)
{
    if (jmmc-auth:checkPassword($email, $password)) then
        let $cookie := response:set-cookie("contact",$email, xs:yearMonthDuration('P10Y'), false())
        return 
            exists(session:set-attribute("email", $email))
    else
        false()
};

declare function jmmc-auth:logout()
{
    (session:remove-attribute("email"), session:set-attribute("email", ()))
};


(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:showLoginForm($node as node()?, $model as map(*)?, $email as xs:string?, $password as xs:string?, $action as xs:string?) {
    jmmc-auth:show-login-form($node, $model, $email, $password, $action) 
};

declare function jmmc-auth:show-login-form($node as node()?, $model as map(*)?, $email as xs:string?, $password as xs:string?, $action as xs:string?) {
 let $email := $email
 let $logout := if($action="logout") then jmmc-auth:logout() else ()
 let $testLogin := if($email and $password) then jmmc-auth:login($email, $password) else ()
 let $user := jmmc-auth:isLogged()
 let $info := jmmc-auth:getInfo($email)
 return
 if($user) then
     <p>Logged as <b>{$user}</b> ( {$info/name/text()}, <em>{$info/affiliation/text()}</em> ) &#160;<a href="login.html?action=logout" class="btn" >Logout</a></p>
     else
         <p>Fill form for login:<br/>
         <form method="post" action="./login.html" class="form-inline">
             <input type="text" name="email" value="{$email}" class="input-xlarge" placeholder="Email"/>
             <input type="password" name="password" class="input-small" placeholder="Password"/>
             <button type="submit" class="btn">Sign in</button>
             &#160;
             <small><a href="https://apps.jmmc.fr/account">visit account management</a></small>
         </form>
         </p>
};

(:~ deprecated, use non camelcase function name ~:)
declare function jmmc-auth:signInMenu($node as node(), $model as map(*)){
    jmmc-auth:sign-in-menu($node , $model)
};

declare function jmmc-auth:sign-in-menu($node as node(), $model as map(*)){
    let $isLogged := jmmc-auth:isLogged()
    let $indexpage := not($isLogged) and contains(request:get-url(),"login.html")
    let $icon := if($indexpage) then "icon-refresh" else if($isLogged) then "icon-ok" else "icon-off"    
    let $title :=   if($indexpage) then
                        "Sign In"
                    else if($isLogged) then
                        "Sign out"
                    else
                        "Sign In"
    let $action :=  if($isLogged) then 
                        "logout"
                    else 
                        "login"            
    let $link := <a href="login.html?action={$action}" class="dropdown" data-toggle="dropdown"><i class="{$icon}"/> {$title} <b class="caret"/></a>
    let $menuitem := <a href="login.html?action={$action}"><i class="{$icon}"/> {$title} </a>
    return 
     <li class="dropdown">
        {$link}
        <ul class="dropdown-menu">
            <li>
                {$menuitem}
            </li>
            <li>
                <a href="http://apps.jmmc.fr/account">
                <i class="icon-lock"/> Create an account</a>
            </li>
        </ul>
    </li>
};
