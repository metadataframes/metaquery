xquery version "3.1";

(:~ 
 :
 : Module name:  Metaquery Utils
 : Module version:  0.0.1
 : Date:  November 4, 2017
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

module namespace mqy-utils = "https://metadatafram.es/metaquery/utils/";
declare namespace mqy = "https://metadatafram.es/metaquery/mqy/";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace err = "http://www.w3.org/2005/xqt-errors";
declare namespace mqy-errs = "https://metadatafram.es/metaquery/mq-errors/";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

declare function mqy-utils:clean-date(
  $date as xs:string?
) as xs:string {
  let $norm :=
    analyze-string($date, "[0-9]")//fn:match 
    => string-join()
  return
    substring($norm, string-length($norm) - 3)              
};

declare function mqy-utils:clean-isbn(
  $isbn as xs:string
) as xs:string {
  replace($isbn, "[^\d|X|x]", "")
};

declare function mqy-utils:clean-string(
  $string as xs:string*
) as xs:string* {
  string-join(
    (for $s in analyze-string($string, ".")//*:match
    return (
      if (not(matches($s, "\\")) and not(matches($s, "&quot;")))
      then
        $s
      else
        ())
    => lower-case()    
    )  
  )               
};

declare function mqy-utils:split-title(
  $data as element(mqy-utils:data)
) as item() { 
  " "||$data/mqy-utils:index/@bool||" &#x28;"|| 
  string-join(
    let $tokens := mqy-utils:stopword-tokens($data/*:title)
    let $words :=
      mqy-utils:stopwords(
        $tokens/mqy-utils:string,
        tokenize($tokens/mqy-utils:string, "\s+"),
        tokenize($tokens/mqy-utils:stopwords, "\n")
      )
    let $word-tokens := tokenize($words, "\s+")
    for $word at $p in $word-tokens
    return (
      $data/*/@name, "=&quot;", $word, "&quot;",      
      if (count(subsequence($word-tokens, $p)) gt 1)
      then
        " "||$data/mqy-utils:index/@bool||" "
      else
        "&#x29;"
    ) 
  ) 
};

declare function mqy-utils:split-keywords(
  $data as element()
) as item() {  
  for $d in $data/mqy-utils:data
  let $index := $d/mqy-utils:index
  return (
  
    
    let $tokens := (
      <mqy-utils:tokens>{
        for $x in $d/*[not(self::*:index) and not(self::*:path)]
        return (
          if (matches($x, "\s+"))
          then (
            for $y in tokenize($x)
            return
              <mqy-utils:token>{$y}</mqy-utils:token>
          )            
          else                      
            <mqy-utils:token>{$x/data()}</mqy-utils:token>            
        ) 
      }</mqy-utils:tokens>
    )
    let $sequence := (
      $tokens//mqy-utils:token
    )
    return
      (: string-join(        
        for $token in $tokens/mqy-utils:token
        return (
          $index/@name||"===&quot;"||$token||"&quot;"
        ), " "||$index/@bool||" "
      ) :)$sequence
    ) => trace()         
  
};

declare function mqy-utils:test-result(
  $title as node()+,
  $record as node()+
) as node()+ {
  for $field in $record
  let $test :=
    <mqy-utils:test>
      <mqy-utils:title>{string-join($title//*:group, " ")}</mqy-utils:title>
      <mqy-utils:record>{
        string-join(
          let $tokens := mqy-utils:stopword-tokens($field)
          let $words := 
            mqy-utils:stopwords(
              $tokens/mqy-utils:string,
              tokenize($tokens/mqy-utils:string, "\s+"),
              tokenize($tokens/mqy-utils:stopwords, "\n")
            )   
          return
            $words  
        )                    
      }</mqy-utils:record>
    </mqy-utils:test>
  return (
    <mqy-utils:test>
      <mqy-utils:result>{
        for-each-pair($test/*:title, $test/*:record, function($t, $r) {
          strings:levenshtein($t, $r)
        })      
      }</mqy-utils:result>
      <mqy-utils:search>
        <mqy-utils:title>{$test/*:title}</mqy-utils:title>
        <mqy-utils:record>{$test/*:record}</mqy-utils:record>
      </mqy-utils:search>
    </mqy-utils:test> => trace()        
  )           
};

declare function mqy-utils:stopwords(
  $string as xs:string?,
  $tokens as xs:string*,
  $stopwords as xs:string*
) as item()* {  
  if ($tokens = $stopwords)
  then (
    if (head($tokens) = $stopwords)
    then (                  
      mqy-utils:stopwords(
        replace($string, "\s?" || head($tokens) || "\s+", " "), 
        tail($tokens), 
        $stopwords
      )
    )    
    else
      mqy-utils:stopwords($string, tail($tokens), $stopwords)
    )
  else  
     $string
};

declare function mqy-utils:stopword-tokens(
  $string as xs:string*
) as element(mqy:tokens) {
  <tokens xmlns="https://metadatafram.es/metaquery/mqy/">{
    <string>{$string}</string>,      
    <stopwords>{
      db:open("stopwords")/*:text/text()
    }</stopwords>
  }</tokens>
};

declare function mqy-utils:tokenizer(
  $data as node()
) as node() {  
  let $tokens := 
    string-join(
      (for $d in $data
      return
        if (matches($d, "\s+")) then () else $d), " "
    ) 
    => normalize-space()
  let $name := name($data)  
  let $string :=
    $data[matches(., "\s")]      
  let $tokens-or-string := mqy-utils:stopword-tokens(($tokens, $string))
  return   
    <mqy:tokens>{
      for $t in tokenize(
        mqy-utils:stopwords(
          $tokens-or-string/mqy:string,
          tokenize($tokens-or-string/mqy:string, "\s+"),
          tokenize($tokens-or-string/mqy:stopwords, "\n")
        )    
      )
      return
        <mqy:token name="{$name}">{$t}</mqy:token>  
    }</mqy:tokens>       
};

declare function mqy-utils:compile-queries( 
  $tokens as element(mqy:tokens) 
) as node()* {    
  let $queries :=
    for $token in $tokens/*
    return
      switch($token/@name)
        case "name" return 
          <mqy:bool index="any">{
            "bath.any=&quot;" || $token || "&quot;"
          }</mqy:bool>
        case "publisher" return 
          <mqy:bool index="any">{
            "bath.any=&quot;" || $token || "&quot;"
          }</mqy:bool>        
        case "date" return
          <mqy:bool index="any">{
            "bath.any=&quot;" || $token || "&quot;"
          }</mqy:bool>
        case "title" return
          <mqy:bool index="title">{
            "dc.title=&quot;" || $token || "&quot;"
          }</mqy:bool>
        default return ()             
  for $query in $queries
  group by $key := $query/@index
  return (
    <mqy:queries index="{$key}">{$query}</mqy:queries>
  )
};

declare function mqy-utils:compile-query-string(  
  $queries as node()*
) as item()* {
  if (exists($queries[@index eq "any"]))
  then (
    string-join(
      concat(
        "&#x28;",
        string-join(
          (for $query in $queries[@index eq "any"]/*
          return
            $query), " OR "  
        ),
        "&#x29; AND &#x28;",
        string-join(
          (for $query in $queries[@index eq "title"]/*
          return
            $query), " AND "
        ),
        "&#x29;"          
      )        
    )    
  )
  else
    $queries[@index eq "title"]/*          
};
