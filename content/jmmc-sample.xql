xquery version "3.0";

(:~
 : replace sample module description.
 : This module is mainly a template for futur ones.
 : 
 :)
module namespace jmmc-sample="http://exist.jmmc.fr/jmmc-resources/sample";

(:~
 : Sample function.
 : 
 : @param $p user input string.
 : @return a constant string followed by given input value.
 :)
declare function jmmc-sample:test($p as xs:string) as xs:string
{
  "test result for input : " || $p
};

