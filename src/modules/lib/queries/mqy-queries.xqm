xquery version "3.1";

module namespace mqy-queries = "https://metadatafram.es/metaquery/queries/";
declare namespace math = "http://www.w3.org/2005/xpath-functions/math";
declare namespace sql = "http://basex.org/modules/sql";
declare namespace mqy-errs = "https://metadatafram.es/metaquery/mqy-errors/";
declare namespace mqy-sql = "https://metadatafram.es/metaquery/sql/";

declare function mqy-queries:simple-query(
  $aliases as element(mqy-sql:aliases)?
) as xs:string {
  ``[
  SELECT bib_text.isbn, 
         Rawtohex(bib_text.author) as author, 
         Rawtohex(yaledb.Getbibsubfield(bib_text.bib_id, ?, ?)) as main_title,
         Rawtohex(yaledb.Getbibsubfield(bib_text.bib_id, ?, ?)) as subtitle
  FROM   bib_text
  WHERE  ROWNUM = ?
  ]``
};

declare function mqy-queries:action-dates(
  $aliases as element(mqy-sql:aliases)?
) as xs:string {
  ``[
  SELECT bib_master.bib_id, bib_master.create_date, bib_history.operator_id, bib_history.action_date
  FROM   bib_master LEFT JOIN bib_history ON bib_master.bib_id = bib_history.bib_id
  WHERE  (bib_history.action_date Between to_date(?, 'yyyy/mm/dd') And to_date (?, 'yyyy/mm/dd'))
  AND    (bib_history.operator_id IN (?))
  ]``
};

declare function mqy-queries:single-bib(
  $aliases as element(mqy-sql:aliases)?
) as xs:string {
  ``[
  SELECT bib_master.bib_id, bib_master.create_date, bib_history.operator_id, bib_history.action_date
  FROM   bib_master LEFT JOIN bib_history ON bib_master.bib_id = bib_history.bib_id
  WHERE  (bib_master.bib_id = ?) 
  ]``
};

declare function mqy-queries:item-stats(
  $aliases as element(mqy-sql:aliases)?
) as xs:string {
  ``[
  SELECT DISTINCT bib_text.bib_id,
         utl_i18n.raw_to_nchar(rawtohex(bib_text.title_brief),'utf8') as title,         
         mfhd_master.mfhd_id,
         mfhd_master.display_call_no as call_num,
         item_barcode.item_id,
         item_barcode.item_barcode,
         bib_history.operator_id,
         bib_history.action_date
  FROM   (((((((bib_text 
          LEFT JOIN bib_history ON bib_history.bib_id = bib_text.bib_id)
          INNER JOIN bib_mfhd ON bib_text.bib_id = bib_mfhd.bib_id)
          INNER JOIN mfhd_master ON bib_mfhd.mfhd_id = mfhd_master.mfhd_id)
          INNER JOIN mfhd_item ON mfhd_master.mfhd_id = mfhd_item.mfhd_id)
          INNER JOIN item_barcode ON mfhd_item.item_id = item_barcode.item_id)
          INNER JOIN item_stats ON mfhd_item.item_id = item_stats.item_id)
          INNER JOIN item_stat_code ON item_stats.item_stat_id = item_stat_code.item_stat_id)  
  WHERE  (bib_history.action_date Between to_date(?, 'yyyy/mm/dd') And to_date (?, 'yyyy/mm/dd'))
  AND    (item_stat_code_desc = 'DGI Filmstudy')
  AND    (bib_history.operator_id IN (?, ?, ?, ?))
  ORDER BY bib_id
  ]``
};

declare function mqy-queries:aspace-notes(
  $aliases as element(mqy-sql:aliases)?  
) as xs:string {
  ``[
  SELECT DISTINCT resource.id
      , resource.ead_id
      , note_persistent_id.persistent_id
      , rr.begin as Begin_Date
      , rr.end as End_Date
      , CAST(note.notes as CHAR (15000) CHARACTER SET UTF8) AS Text
      , CONCAT(?, resource.repo_id, ?, resource.id) AS Resource_URL
  FROM note
  LEFT JOIN note_persistent_id on note.id=note_persistent_id.note_id
  LEFT JOIN resource on note.resource_id=resource.id
  LEFT JOIN rights_restriction rr on rr.resource_id = resource.id
  WHERE resource.repo_id = 12 #enter your repo_id here
  AND note.notes LIKE '%accessrestrict%' 
  OR note.notes LIKE '%userestrict%'
  #OR (rr.restriction_note_type LIKE '%accessrestrict%' OR rr.restriction_note_type LIKE '%userestrict%');
  ]``
};

declare function mqy-queries:aspace-schema(
  $aliases as element(mqy-sql:aliases)?  
) as xs:string {
  ``[    
    SELECT * FROM information_schema.key_column_usage
  ]``
};