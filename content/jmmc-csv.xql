xquery version "3.0";

(:~
 : This module transform a given csv string buffer (CSV - RFC4180) into a table element.
 : 
 : @note It does not support multi line records.
 :)
module namespace jmmc-csv="http://exist.jmmc.fr/jmmc-resources/csv";


(:~
 : Return a table element to represent the given records in CSV format.
 : 
 : @note It does not support multi line records.
 : 
 : @param $data the CSV content
 : @param $field-sep the CSV separator
 : @return a sequence of CSV records
 :)
declare function jmmc-csv:csv-to-xml($data as xs:string, $field-sep as xs:string) as node() {
    <table>
        {
            for $row in jmmc-csv:csv-records($data)
            return <tr>
                {
                    for $field in jmmc-csv:csv-fields(tokenize($row, $sep))
                    return <td>{$field}</td>
                }
                </tr>
        }
    </table>
};


(:~
 : Return records from CSV data.
 : 
 : @note It does not support multi line records.
 : 
 : @param $data the CSV content
 : @return a sequence of CSV records
 :)
declare function jmmc-csv:csv-records($data as xs:string) as xs:string* {
    tokenize($data, '\n')
};

(:~
 : Return items of the first escaped field from a tokenized CSV record.
 : 
 : @param $tokens remaining items from a tokenized record
 : @return the items of a CSV escaped field
 :)
declare function jmmc-csv:csv-escaped-field($tokens as xs:string*) as xs:string* {
    let $head := head($tokens)
    return (
        $head,
        if(empty($head) or matches($head, '[^"]"\s*$')) then () else jmmc-csv:csv-escaped-field(tail($tokens))
    )
};

(:~
 : Parse a tokenized CSV record.
 : 
 : @params $tokens a tokenized CSV record
 : @return a sequence of CSV fields
 :)
declare function jmmc-csv:csv-fields($tokens as xs:string*) as xs:string* {
    (: check for escaped field :)
    let $escaped := matches($tokens[1], '^\s*"')
    let $field := if ($escaped) then jmmc-csv:csv-escaped-field($tokens) else head($tokens)
    let $rest  := subsequence($tokens, count($field) + 1)
    (: reassemble and unescape field if necessary :)
    let $field := if ($escaped) then replace(replace(string-join($field, ','), '^\s*"|"\s*$', ''), '""', '"') else $field

    return ( $field, if (empty($rest)) then () else jmmc-csv:csv-fields($rest) )
};

