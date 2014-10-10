xquery version "3.0";

(:~
 : Module wrapping oiexplorer existdb extension.
 :)

module namespace jmmc-oiexplorer="http://exist.jmmc.fr/jmmc-resources/oiexplorer";

import module namespace oi="http://exist.jmmc.fr/extension/oiexplorer" at "java:fr.jmmc.exist.OIExplorerModule";

(:~
 : Parse OIFits data with JMMC's OIFits Explorer and return XML description.'
 : 
 : @param $data a URL or binary content to parse
 : @return XML description of OIFits content
 : @error failed to parse data as OIFits
 :)
declare function jmmc-oiexplorer:to-xml($data as item()) {
    oi:to-xml($data)
};

(:~
 : Validate data as OIFits data using JMMC's OIFits Explorer.
 : 
 : If the data is invalid, an error is raised.
 : 
 : @param $data a URL or binary content to check
 : @return nothing
 : @error failed to parse data as OIFits
 :)
declare function jmmc-oiexplorer:check($data as item()) as empty() {
    oi:check($data)
};
