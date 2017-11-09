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
import module namespace mqy-sql = "https://metadatafram.es/metaquery/sql/" at
"mq-sql.xqm";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace err = "http://www.w3.org/2005/xqt-errors";
declare namespace mqy-errs = "https://metadatafram.es/metaquery/mq-errors/";
declare namespace marc = "http://www.loc.gov/MARC21/slim";


declare function mqy:options-to-url(
  $options as element(mqy:options)
) as element(mqy:sru) {
  <sru
    xmlns="https://metadatafram.es/metaquery/mqy/">
    <head>
      {
        $options/base
        || $options/db
        || "?version=1.1&amp;operation="
        || $options/op
        || "&amp;query="
      }
    </head>
    <tail>
      {
        "&amp;startRecord="
        || $options/start
        || "&amp;maximumRecords="
        || $options/max
        || "&amp;recordSchema="
        || $options/schema
      }
    </tail>
  </sru>
};

declare function mqy:clean-isbn(
$isbn as xs:string
) as xs:string {
  replace($isbn, "[^\d|X|x]", "")
};

declare function mqy:map-query(
$data as item()*,
$maps as element(mqy:mappings)
) as element(mqy:mapped) {
  <mapped
    xmlns="https://metadatafram.es/metaquery/mqy/"
    data="{string-join($data//*, "--")}"    
    hash="{mqy:hash-data(string-join($data//*, "--"))}">{
      for $map in $maps/mqy:mapping/mqy:data,
        $d in $data/*
        [
          normalize-space(.) and (            
            for $m in $map/*
            return (
              if ($m/@match eq "element-name")
              then (
                for $name in $map//@name
                where name(.) eq $name
                return
                  true()
              )              
              else
                false()
            )              
          ) => distinct-values()
        ]
      return (      
        copy $m := $map
        modify (                                     
          if ($m/@type eq "name")
          then
            if (matches($d, "\s+"))
            then (
              let $names := tokenize($d, "\s+")
              for $name in $names
              let $cleaned := (
                replace($name, "[\\|&quot;|&apos;|?|:|.|,|;|/]", " ")
                => lower-case()
                => normalize-space()
                => encode-for-uri()
              )                               
              return
                if (normalize-space($cleaned))
                then (                  
                  delete node $m//mqy:data[@name],
                  insert node <name xmlns="">{$d}</name> 
                    into $m//mqy:data[@type]
                )
                else
                  ()
            )              
            else (
              delete node $m//mqy:data[@name],
              insert node <name xmlns="">{$d}</name> 
                into $m//mqy:data[@type]
            )                            
          else (
            if ($m/@type eq "date")
            then (
              insert node <date xmlns="">{mqy:clean-date($d)}</date>
                into $m              
            )
            else (
              if ($m/@type eq "publisher")
              then (
                insert node(
                  <publisher xmlns="">{
                    replace($d, "[\\|&quot;|&apos;|?|:|.|,|;|/]", " ")
                    => lower-case()
                    => normalize-space()
                    => encode-for-uri()
                  }</publisher>
                ) into $m                
              )
              else (
                delete node $m/mqy:data[@name],
                insert node $d into $m                
              )
            )
          )                                
        )
      return $m      
      )            
  }</mapped> => trace() 
};

declare function mqy:build-query(
$mapped as element(mqy:mapped)
) as element(mqy:queries) {
  <queries 
    xmlns="https://metadatafram.es/metaquery/mqy/"
    data="{$mapped/@data}"
    hash="{$mapped/@hash}">
    {
      for $m in $mapped/mqy:mappings/mqy:mapping
      let $i := $m/mqy:index,
        $b := $i/@bool,
        $data := $m/mqy:data
      for $d in $data/*[normalize-space(.)]
      return
        <query 
          index="{$i}"
          bool="{$b}">
          {
            if ($i eq "dc.title")
            then 
              (
              attribute {"title"} {$d},
              lower-case(replace($d, "[\\|&quot;|?|:|.|,|;|/]", "")) 
              => normalize-space()
                  
              )              
            else              
              if ($i eq "local.isbn")
              then
                mqy:clean-isbn($d)
            else
              if (name($d) ne "name")
              then
                (
                lower-case(replace($d, "[\\|&quot;|?|:|.|,|;|/]", " ")) 
                => normalize-space()
                => encode-for-uri()  
                )              
              else
                if (name($d) eq "date")
                then (
                  attribute {"date"} {$d},
                  $d 
                  => normalize-space()
                  => encode-for-uri()  
                )
                else                
                  $d => normalize-space() => encode-for-uri()  
          }
        </query>
    }
  </queries> 
};

declare function mqy:compile-query-string(
$sru as element(mqy:sru),
$query as xs:string?
) as xs:anyURI {
  xs:anyURI($sru/mqy:head || $query || $sru/mqy:tail) => trace()
};

declare function mqy:run-isbn(
$queries as element(mqy:queries)
) as item() {
  if ($queries/mqy:query[normalize-space(.)][@index = "local.isbn"])
  then 
    "local.isbn=" || $queries/mqy:query[@index eq "local.isbn"] 
  else
    <mqy:message hash="{$queries/@hash}">No ISBN to query.</mqy:message>
};

declare function mqy:run-keywords-title(
$queries as element(mqy:queries)
) as item()* {  
  (for $query at $p in $queries/mqy:query[not(@index eq "local.isbn")]
    return            
      if ($p eq 1 and $query/@index eq "dc.title")
      then
        <mqy:message hash="{$queries/@hash}">No keywords to query.</mqy:message>
      else
        if ($p eq 1 and $query/@index ne "dc.title")
        then
          "(" 
          || $query/@index 
          || "=" 
          || "&quot;"
          || $query
          || "&quot;"       
        else
          if ($p gt 1 and $p le 10 and $query/@index ne "dc.title")
          then
            mqy:split-keywords($query)
          else
            if ($p gt 1 and $query/@index eq "dc.title")
            then (
              mqy:split-title($query)
            )            
            else ()) => string-join()
};

declare function mqy:run-title(
$queries as element(mqy:queries)
) as item()* {  
  let $title := $queries/mqy:query[normalize-space(.)][@index = "dc.title"]
  return
  if ($title and count(tokenize($title)) gt 1)
  then     
    string-join(
       let $tokens := mqy:stop-tokens($title),
         $words := mqy:stop-words(
           $tokens/mqy:str,
           tokenize($tokens/mqy:str, "\s+"),
           tokenize($tokens/mqy:stops, "\n")
         )
       return
         if (count($words) gt 1)
         then
           for $word at $p2 in tokenize($words, "\s+")
           return (                                                      
             $title/@index, 
             "=", 
             "&quot;", 
             $word, 
             "&quot;",
             if (substring-after($words, $word))
             then
               " " || $title/@bool || " "
             else
               ()                      
           )
         else 
           ()
    ) 
  else
    <mqy:message hash="{$queries/@hash}">No title to query.</mqy:message>
};

declare function mqy:split-title(
$query as item()*
) as item() {
  ") "           
  || $query/@bool 
  || " ("
  || string-join(
       let $tokens := mqy:stop-tokens($query),
         $words := mqy:stop-words(
           $tokens/mqy:str,
           tokenize($tokens/mqy:str, "\s+"),
           tokenize($tokens/mqy:stops, "\n")
         ),
         $word-tokens := tokenize($words, "\s+")       
       for $word at $p2 in $word-tokens
       return (                                                      
          $query/@index, 
          "=", 
          "&quot;", 
          $word, 
          "&quot;",                    
          if (count(subsequence($word-tokens, $p2)) gt 1)
          then            
            " " || $query/@bool || " "
          else
            ()
       )) 
  || ")" 
};

declare function mqy:split-keywords(
$query as item()*
) as item() {
  string-join(
    let $tokens := tokenize($query, "\s+")
      return
        for $word at $p in $tokens
          return (
            " "
            || $query/@bool 
            || " " 
            || $query/@index 
            || "=" 
            || "&quot;"
            || $word
            || "&quot;"
          ) 
  )
};

declare function mqy:try-query(
$queries as element(mqy:queries),
$run-query as function(element(mqy:queries)) as item()*,
$sru as element(mqy:sru)
) as item()* {
  let $try :=
    mqy:run-queries($queries, $run-query, $sru),
    $query := $run-query($queries)
  return
    (
    if ($try//marc:record)
    then (
      <mqy:message 
        data="{$queries/@data}"
        hash="{$queries/@hash}" 
        title="{distinct-values($queries//@title)}">Success: {$query}</mqy:message>,
      $try
    )
      
    else
      (
      typeswitch($query)
        case element() return $query
        default return 
          if ($query)
          then
            <mqy:message hash="{$queries/@hash}">No results for: {$query}</mqy:message>
          else 
            ()
      )
    )
};

declare function mqy:run-queries(
$queries as element(mqy:queries),
$run-query as function(element(mqy:queries)) as item(),
$sru as element(mqy:sru)
) as item()* {  
  try
  {
    let $query := $run-query($queries)
    return
      typeswitch($query)
        case element() return $query
        case xs:string return 
          mqy:send-query($queries, mqy:compile-query-string($sru, $query))       
        default return ()    
  }
  catch *
  {
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

declare function mqy:hash-data(
$data as item()
) as xs:string {
  string($data) => hash:sha256() => xs:hexBinary() => xs:string() => lower-case()  
};

declare function mqy:clean-date(
$date as xs:string?
) as xs:string {
  let $norm :=
    analyze-string($date, "[0-9]")//fn:match 
    => string-join()
  return
    substring($norm, string-length($norm) - 3)              
};

declare function mqy:stop-words(
$str as xs:string?,
$tokens as xs:string*,
$stops as xs:string+
) as item()* {  
  if ($tokens = $stops)
  then
    if (head($tokens) = $stops)
    then
      (                  
      mqy:stop-words(replace($str, "\s?" || head($tokens) || "\s+", " "), 
                    tail($tokens), 
                    $stops)
      )    
    else
      mqy:stop-words($str, tail($tokens), $stops)
  else 
    (    
     lower-case(replace($str, "[\\|&quot;|&apos;|?|:|.|,|;|/]", " ")) 
     => normalize-space()
    )
};

declare function mqy:stop-tokens(
$str as xs:string?
) as element(mqy:tokens) {
  <tokens xmlns="https://metadatafram.es/metaquery/mqy/">
    {
      <str>{lower-case($str)}</str>,      
      <stops>
        {
          fetch:text("http://files.basex.org/etc/stopwords.txt")
          || "&#10;"
          || "-"          
        }
      </stops>
    }
  </tokens>  
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
                mqy:stop-words(
                  mqy:stop-tokens($title)/mqy:str,
                  tokenize(mqy:stop-tokens($title)/mqy:str, "\s+"),
                  tokenize(mqy:stop-tokens($title)/mqy:stops, "\n")
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

declare function mqy:parse(
  $node as node()
) as item()* {
  typeswitch($node)       
    case element(labelOrSubject) return mqy:process-subject($node)
    case element(predicateObjectList) return mqy:process($node)
    case element(verb) return mqy:process-predicate($node)
    case element(object) return mqy:process-object($node)
    case text() return $node  
    default return mqy:process($node)
};

declare function mqy:p(
  $triples as node()*
) as item()* {
  for $triple in $triples
  return
    if ($triple instance of element(labelOrSubject))
    then (
      <statement>{
        <subject>{$triple}</subject>,
        mqy:p($triple)
      }</statement>
    )
    else 
      ()
      
};


declare function mqy:process-subject(
  $nodes as node()*
) as item()* {
  <subject>{for $node in $nodes/node() return mqy:parse($node)}</subject>
};

declare function mqy:process-predicate(
  $nodes as node()*
) as item()* {
  <predicate>{for $node in $nodes/node() return mqy:parse($node)}</predicate>  
};

declare function mqy:process-object(
  $nodes as node()*
) as item()* {
  <object>{for $node in $nodes/node() return mqy:parse($node)}</object>
};

declare function mqy:process(
  $nodes as node()*
) as item()* {
  for $node in $nodes/node() return mqy:parse($node)
};

declare function mqy:for-each-triple($seq1, $seq2, $seq3, $f)
{
   if(exists($seq1) and exists($seq2) and exists($seq3)) 
   then (
     $f(head($seq1), head($seq2), head($seq3)),
     mqy:for-each-triple(tail($seq1), tail($seq2), tail($seq3), $f)
   )
   else ()
};
