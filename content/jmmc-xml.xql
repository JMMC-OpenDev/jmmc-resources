xquery version "3.0";

(:~
 : This module provide some utility functions related to xml.
 : 
 :)
module namespace jmmc-xml="http://exist.jmmc.fr/jmmc-resources/xml";

(:~ 
 : Return a deep copy of the elements with out namespaces.
 : ( from http://en.wikibooks.org/wiki/XQuery/Filtering_Nodes#Removing_unwanted_namespaces )
 : @param $element the source element ( with or without associated namespace )
 : @return a copy of the input element without associates namespace.
 :)
declare function jmmc-xml:strip-ns($elements as element()*) as element()* {
    for $element in $elements return
       element { QName((), local-name($element)) } {
           for $child in $element/(@*,*, text(), comment())
           return
               if ($child instance of element())
               then jmmc-xml:strip-ns($child)
               else $child
       }
};
