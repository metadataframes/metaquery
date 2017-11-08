import module namespace mqy-sql = "https://metadatafram.es/metaquery/sql/" 
  at "../lib/sql/mqy-sql.xqm";
import module namespace mqy-queries = "https://metadatafram.es/metaquery/queries/"
  at "../lib/queries/mqy-queries.xqm";

declare variable $mqy-sql:CONNECT := "";
declare variable $mqy-sql:USER := "";
declare variable $mqy-sql:PW := "";

let $creds :=
  <params>
    <conn>
      <uri>jdbc:mysql://{$mqy-sql:CONNECT}</uri>
      <user>{$mqy-sql:USER}</user>
      <pw>{$mqy-sql:PW}</pw>
    </conn>
  </params>  
let $params :=
  <sql:parameters>    
    <sql:parameter type="string">/repositories/</sql:parameter>              
    <sql:parameter type="string">/archival_objects/</sql:parameter>   
  </sql:parameters>
let $conn := mqy-sql:connect($creds/conn/uri, $creds/conn/user, $creds/conn/pw)
let $sql :=
  mqy-queries:aspace-notes(())
return (
  <mqy-sql:results>{
    (mqy-sql:prepared(
      $conn, 
      $params, 
      $sql
    ))
  }</mqy-sql:results> 
)
