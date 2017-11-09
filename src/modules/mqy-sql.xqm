xquery version "3.1";

(:~ 
 :
 : Module name:  Metaquery SQL
 : Module version:  0.0.1
 : Date:  September 12, 2017
 : License: GPLv3
 : XQuery extensions used: BaseX SQL Module
 : XQuery specification: 3.1
 : Module overview: An XRX framework and set of XQuery functions for harvesting 
 : MARC records from OCLC for copy cataloging.
 : Dependencies: BaseX, XSLTForms, Index Data's Metaproxy, MarcEdit 
 : @author @timathom
 : @version 0.0.1
 : @see https://github.com/timathom/metaquery
 : @see http://docs.basex.org/wiki/SQL
 :
:)

module namespace mqy-sql = "https://metadatafram.es/metaquery/sql/";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace err = "http://www.w3.org/2005/xqt-errors";

(:~ 
 : 
 : 
 : 
 : @param $db-uri as xs:anyURI
 : @param $db-user as xs:string
 : @param $db-pw as xs:string
 : @return connection handle
 : @error BXSQ0001: an SQL exception occurs, e.g., missing JDBC driver or no 
 : existing relation. 
 :
 :)
declare function mqy-sql:connect(
$db-uri as xs:anyURI,
$db-user as xs:string,
$db-pw as xs:string
) as item() {
  try
  {
    sql:connect($db-uri, $db-user, $db-pw)
  }
  catch *
  {
    <mqy-sql:error>
      {
        "Error ["
        || $err:code
        || "]: "
        || $err:line-number
        || "&#10;"
        || $err:additional
        || "&#10;"
        || $err:description
      }
    </mqy-sql:error>
  }
};

(:~ 
 : 
 : 
 : 
 : @return Results of executing SQL prepared statement
 : @error BXSQ0001: an SQL exception occurs, e.g., missing JDBC driver or no 
 : existing relation. 
 : @error BXSQ0003: number of parameters differs from number of placeholders
 :
 :)
declare function mqy-sql:prepared(
$conn as item(),
$params as element(sql:parameters),
$sql as xs:string
) as element()+ {
  let $query :=
  try
  {
    sql:execute-prepared(sql:prepare($conn, $sql), $params),
    sql:close($conn)
  }
  catch *
  {
    <mqy-sql:error>
      {
       
        "Error ["
        || $err:code
        || "]: "
        || $err:line-number
        || "&#10;"
        || $err:additional
        || "&#10;"
        || $err:description
        
      }
    </mqy-sql:error>
  }
  return
    (
    if ($query[self::mqy-sql:error] or $query[self::sql:row])
    then
      $query
    else
      <mqy-sql:message>No results for the query: {$sql}</mqy-sql:message>
    )
};