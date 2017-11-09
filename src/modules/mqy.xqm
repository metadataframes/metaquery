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

module namespace mqy = "https://metadatafram.es/metaquery/mqy/";
import module namespace mqy-query = "https://metadatafram.es/metaquery/query/" 
  at "mqy-query.xqm";
import module namespace mqy-utils = "https://metadatafram.es/metaquery/utils/" 
  at "mqy-utils.xqm";
import module namespace mqy-sql = "https://metadatafram.es/metaquery/sql/" 
  at "mqy-sql.xqm";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace err = "http://www.w3.org/2005/xqt-errors";
declare namespace mqy-errs = "https://metadatafram.es/metaquery/mq-errors/";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

declare function mqy:map-query(
  $data as node()+,
  $mappings as document-node()
) as document-node() {
  document {
    <mapped xmlns="https://metadatafram.es/metaquery/mqy/">{
      for $d in $data/*[normalize-space(.)],
        $mapping in 
          $mappings/*/*/mqy:data[@type][
            if (
              @name eq name($d) or (
                for $n in mqy:data[@name eq name($d)] 
                return 
                  true()  
              )
            )
            then
              true()
            else
              false()
          ]
      let $index := $mapping/../index
      return (
        copy $mapped := $mapping
        modify (          
          switch($mapped/@type)
            case "isbn" return
              insert node (
                <isbn xmlns="">{mqy-utils:clean-isbn($d)}</isbn>,
                $index
              ) into $mapped
            case "title" return
              insert node (
                <title xmlns="">{mqy-utils:clean-string($d)}</title>,
                $index
              ) into $mapped
            case "publisher" return
              insert node (
                <publisher xmlns="">{mqy-utils:clean-string($d)}</publisher>,
                $index
              ) into $mapped
            case "date" return
              insert node (
                <date xmlns="">{mqy-utils:clean-date($d)}</date>,
                $index
              ) into $mapped
            case "name" return (              
              delete node $mapped/mqy:data,
              if (matches($d, "\s+"))
              then (
                for $part in tokenize($d, "\s+")
                return (                                    
                  insert node (
                    <name xmlns="">{mqy-utils:clean-string($part)}</name>,
                    $index
                  ) into $mapped
                )
              )
              else (
                insert node (
                  <name xmlns="">{mqy-utils:clean-string($d)}</name>,
                  $index
                ) into $mapped
              )            
            )
            default return ()  
          )      
          return 
            $mapped
      )                
    }</mapped>
  }
};

declare function mqy:group-query(  
  $mapped as document-node()
) as document-node() {
  document {
    <mapped xmlns="https://metadatafram.es/metaquery/mqy/">{
      for $m in $mapped/mqy:mapped/mqy:data
      group by $key := $m/@type      
      return
        <data type="{$key}">{
          if (count($m/mqy:index) gt 1)
          then (            
            for $element in $m/*
            order by name($element)
            group by $key := name($element)
            return (
              if ($element[self::mqy:index or self::mqy:path])
              then
                $element[1]
              else
                $element  
            )              
          )
          else (
            for $element in $m/*
            order by name($element)
            return $element
          )
        }</data>
    }</mapped>  
  }  
};

declare function mqy:options-to-url(
  $options as document-node()
) as document-node() {
  document {
    <sru xmlns="https://metadatafram.es/metaquery/mqy/">
      <head>{
        $options/*/base
        ||$options/*/db
        || "?version=1.1&amp;operation="
        || $options/*/op
        || "&amp;query="
      }</head>
      <tail>{
        "&amp;startRecord="
        || $options/*/start
        || "&amp;maximumRecords="
        || $options/*/max
        || "&amp;recordSchema="
        || $options/*/schema
      }</tail>  
    </sru>    
  }  
};

declare function mqy:compile-query-string(
  $sru as document-node(),
  $query as xs:string?
) as xs:anyURI {
  xs:anyURI($sru/*/mqy:head||$query||$sru/*/mqy:tail)
};

declare function mqy:try-query(
  $mapped as document-node(),
  $queries as function(*),
  $sru as document-node()
) as item()* {
  let $try :=
    mqy:run-queries($mapped, $queries, $sru)
  let $query := $queries($mapped)
  return (
    if ($try//marc:record)
    then (
      <mqy:message>{
        <mqy:status>success</mqy:status>,
        <mqy:query>{$query}</mqy:query>,
        let $title := 
          analyze-string(mqy-query:query-title($mapped), "&quot;(.*?)&quot;")
        let $q := $query
        let $path := $mapped//*[@type eq "title"]/*:path/@code/data()
        let $record := 
          $try//marc:record/xquery:eval((xs:string($path) => normalize-space()), map {"": .})
        return (
          if (matches($query, "local.isbn"))
          then (
            if (mqy-utils:test-result($title, $record)/*:result >= 0.75)
            then
              $try
            else
              ()
          )
          else (
            if (matches($query, "bath.any"))
            then (
              if (mqy-utils:test-result($title, $record)/*:result >= 0.75)
              then
                $try
              else
                ()
            )                          
            else
              if (not(matches($query, "bath.any") and matches($query, "dc.title")))
              then (                
                if (mqy-utils:test-result($title, $record)/*:result >= 0.75)
                then
                  $try
                else
                  ()
              )
              else
                () 
          )         
        )                   
      }</mqy:message>
    )      
    else (
      typeswitch($query)
        case element() return $query
        default return 
          if (exists($query))
          then
            <mqy:message>No results for: {$query}</mqy:message>
          else 
            ()
    )
  )
};

declare function mqy:run-queries(
  $mapped as document-node(),
  $queries as function(*),
  $sru as document-node()
) as item()* {  
  try {
    let $query := $queries($mapped)
    return
      typeswitch($query)
        case element() return $query
        case xs:string return 
          mqy:send-query($mapped, mqy:compile-query-string($sru, $query))       
        default return ()    
  }
  catch * {
    <error
      xmlns="https://metadatafram.es/metaquery/mqy/">
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
    </error>
  }
};

(:~ 
 : Helper for submitting query
 :)
declare function mqy:send-query(
$queries as item(),
$href as xs:anyURI
) as element(mqy:response) {
  <response
    xmlns="https://metadatafram.es/metaquery/mqy/"
    hash="{$queries/@hash}">  
    {  
      try
      {
        http:send-request(
          <http:request
            method="get"
            href="{$href}"/>
        )
      }
      catch *
      {
        <error xmlns="https://metadatafram.es/metaquery/mqy/">
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
        </error>
      }
    }
  </response>
};


(:~ 
 : Filter results
 :)

(:~ 
 : Calculate matching scores
 :
 :)
(: declare function mqy:calculate-match(
$data as item()*
) as item()* {
  
  let $title-tokens := mqy:stop-tokens($query),
    $
    
  let $tokens := ,
    $words := mqy:stop-words(
      $tokens/mqy:str,
      tokenize($tokens/mqy:str, "\s+"),
      tokenize($tokens/mqy:stops, "\n")
    ),
    $word-tokens := tokenize($words, "\s+")       
         
  let $check :=
        mqy:check-title(
        *:datafield[@tag = "245"]/*:subfield[@code = "a"],
        $local
        )
        return
          if ($check = true())
          then
            true()
          else
            false()
            
            
         
}; :)

(:~ 
  : Filter cataloging level, etc.
  :)
declare function mqy:filter-levels(
$marc as element(marc:record),
$filters as element(mqy:filters)
) as element()* {
  if (
  $marc
  [
  *:leader/substring(., 7, 1) = $filters/mqy:biblevel
  and *:leader/substring(., 18, 1) = xquery:eval($filters/mqy:catlevel)
  ]
  )
  then
    $marc
  else
    <mqy:message
      code="0">
      {
        $marc
      }
    </mqy:message>
};

declare function mqy:filter-results(
$results as document-node()
) as item()* {
  <filtered xmlns="https://metadatafram.es/metaquery/mqy/">
  {
    for $result in $results//(mqy:message | mqy:response)
    group by $key := $result/@hash
    return
      <mqy:data key="{$key}">{    
        let $local-title := (
          string-join(
            ($result[self::mqy:message]
                   [following-sibling::*[1][self::mqy:response]]  
            => analyze-string("title=&quot;(.*?)&quot;"))//fn:group,
            " "
          )
        )
        let $record := (
          $result//marc:record[
            let $found-title :=
              (marc:datafield[@tag = "245"]/marc:subfield[@code = "a"])
            let $title-check :=
              for $found in $found-title
              let $title := xs:string($found),
              $tokens :=
                mqy-utils:stopwords(
                  mqy-utils:stopword-tokens($title)/mqy:str,
                  tokenize(mqy-utils:stopword-tokens($title)/mqy:str, "\s+"),
                  tokenize(mqy-utils:stopword-tokens($title)/mqy:stops, "\n")
                )
              for $token in $tokens
              return
                mqy:check-title($token, $local-title)
            return
              $title-check
          ]
        )
        return
          if ($record)
          then (
            $record//ancestor::mqy:response/preceding-sibling::*[1]
                   [self::mqy:message]/@data,
            $record
          )
          else
            ()
                       
        
     
        
        
          
      }</mqy:data>
  }
    
  </filtered>
};

(:~ 
 : Check titles
 :)
declare function mqy:check-title(
$local-title as xs:string*,
$found-title as xs:string*
) as xs:anyAtomicType {
  if (normalize-space($local-title))
  then
    try
    {
      if (strings:levenshtein($found-title, $local-title) ge 0.75)
      then
        true()
      else
        false()
    }
    catch *
    {
      false()
    }
  else
    false()
};

(:~ 
 : Prune fields
 :)
declare function mqy:prune-fields(
$record as element()
) as element(marc:record) {
  copy $r := $record
    modify (
    delete node $r/*[starts-with(@tag, "9")],
    delete node $r/*[@tag eq "029"]
    )
    return
      $r
};

(:~ 
 : Write MARC21
 :)
declare function mqy:write-marc21(
$id as xs:string,
$path as xs:string,
$options as element(mqy:options)
) {
  
  let $store :=
  proc:execute(
  "mono",
  ($options/mqy:MarcEdit/string(),
  "-s",
  $path,
  "-d",
  $options/mqy:marc21
  || $id
  || "marc-"
  || random:uuid()
  || ".dat",
  "-xmlmarc",
  "-marc8")
  )
  return
    $store
};

(:~ 
 : Write all MARC21 files to folder
 :)
declare function mqy:write-all-marc21(
$records as item(),
$options as element(mqy:options)
) {
  for $record in $records//mqy:best//marc:record
  let $file := $record/*:datafield[@tag = "010"]/*:subfield
  => normalize-space()
  return
    (
    file:write(
    $options/mqy:marcxml
    || $file
    || "marc-"
    || random:uuid()
    || ".xml", $record
    ),
    mqy:write-marc21($record, (), $options)
    )

};


