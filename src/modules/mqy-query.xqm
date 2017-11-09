xquery version "3.1";

(:~ 
 :
 : Module name:  Metaquery Main
 : Module version:  0.0.1
 : Date:  September 12, 2017
 : License: GPLv3
 : XQuery extensions used: 
 : XQuery specification: 3.1
 : Module overview: An XRX framework and set of XQuery functions for harvesting 
 : MARC records from OCLC for copy cataloging.
 : Dependencies: BaseX, XSLTForms, Index Data's Metaproxy, MarcEdit 
 : @author @timathom
 : @version 0.0.1
 : @see https://github.com/timathom/metaquery
 :
:)

module namespace mqy-query = "https://metadatafram.es/metaquery/query/";
import module namespace mqy-utils = "https://metadatafram.es/metaquery/utils/" 
  at "mqy-utils.xqm";
import module namespace mqy-sql = "https://metadatafram.es/metaquery/sql/" 
  at "mqy-sql.xqm";
declare namespace mqy = "https://metadatafram.es/metaquery/mqy/";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace err = "http://www.w3.org/2005/xqt-errors";
declare namespace mqy-errs = "https://metadatafram.es/metaquery/mq-errors/";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

declare function mqy-query:query-title(
  $data as node()
) as node() {  
  mqy-utils:tokenizer($data//mqy:data/*:title)  
};

declare function mqy-query:query-keywords-and-title(
  $data as node()
) as node() {
  <mqy:tokens>{
    for $d in $data//mqy:data/*[text()]
    return
      mqy-utils:tokenizer($d)/*
  }</mqy:tokens>  
};