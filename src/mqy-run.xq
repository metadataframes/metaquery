xquery version "3.1";

import module namespace mqy = "https://metadatafram.es/metaquery/mqy/"
  at "modules/mqy.xqm";
import module namespace mqy-query = "https://metadatafram.es/metaquery/query/" 
  at "modules/mqy-query.xqm";
import module namespace mqy-utils = "https://metadatafram.es/metaquery/utils/" 
  at "modules/mqy-utils.xqm";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

(:
let $norm := ft:normalize(?, map { 'stemming': true() })
return strings:levenshtein($norm("HOUSES"), $norm("house"))
:)


let $mappings := db:open("mappings"),
  $sru := mqy:options-to-url(db:open("options")),    
  $results :=
    (let $data :=
      for $n in reverse(3 to 3)
      return
        db:open("csv" || $n)/*
      
    for tumbling window $w in $data/*
      start at $s when true()
      end at $e when $e mod 5 eq 0
    return $w)[position() eq 6]
return          
  let $queries := mqy:group-query(mqy:map-query($results, $mappings))
  return 
    $queries => mqy-query:query-keywords-and-title() => mqy-utils:compile-queries() => mqy-utils:compile-query-string()
  (: let $func := function() {
    for $q in $results
    let $score := <score>{xs:double("0.0")}</score>
    let $queries := mqy:group-query(mqy:map-query($q, $mappings)),
      $isbn := 
        mqy:try-query($queries, mqy:query-isbn#1, $sru),      
      $result :=
        typeswitch($isbn)
          case element(mqy:message) return (
          $isbn,          
          let $keywords-title := 
            mqy:try-query($queries, mqy:query-keywords-and-title#1, $sru)
          return (
            typeswitch($keywords-title)
              case element(mqy:message) return (
                $keywords-title,
                let $title :=
                  mqy:try-query($queries, mqy:query-title#1, $sru)
                return
                  typeswitch($title)
                    case element(mqy:message) return $title
                    default return $title
                )
              default return $keywords-title
            )
          )
        default return $isbn
      return
        $result
  }
  return (
    let $result := xquery:fork-join($func)
    return    
      insert node <mqy:results>{
        for $r in $result
        return
          $r
      }</mqy:results> 
        into db:open("result")/*
  ) :)
  

  



      
      

