xquery version "3.1";

import module namespace mqy = "https://metadatafram.es/metaquery/mqy/"
at "modules/mqy.xqm";
declare namespace marc = "http://www.loc.gov/MARC21/slim";

declare variable $mqy:STEM := "/Users/tt434";

if (db:exists("options"))
then (
  db:drop("options"),
  db:create("options", doc("../config/mq-options.xml"), "options")
)
else
  db:create("options", doc("../config/mq-options.xml"), "options"),

if (db:exists("records"))
then (
 db:drop("records"),
 db:create("records", <mqy:records/>, "records")
)
else
  db:create("records", <mqy:records/>, "records"),

if (db:exists("mappings"))
then (
  db:drop("mappings"),
  db:create("mappings", doc("../config/mq-mappings.xml"), "mappings")
)
else
  db:create("mappings", doc("../config/mq-mappings.xml"), "mappings"),

if (db:exists("result"))
then (
  db:drop("result"),
  db:create("result", <result/>, "result")
)
else
  db:create("result", <result/>, "result"),

if (db:exists("stopwords"))
then 
  ()
else
  db:create(
    "stopwords", 
    <text>{
      fetch:text("http://files.basex.org/etc/stopwords.txt")|| "-"
    }</text>,
    "stopwords"    
  ),

if (file:exists($mqy:STEM||"/Desktop/oclc/marcxml/"))
then
  file:delete($mqy:STEM||"/Desktop/oclc/marcxml/", true())
else
  (),
  
if (file:exists($mqy:STEM||"/Desktop/oclc/marc21/"))
then
  file:delete($mqy:STEM||"/Desktop/oclc/marc21/", true())
else
  (),
  
file:create-dir($mqy:STEM||"/Desktop/oclc/marcxml/"),
file:create-dir($mqy:STEM||"/Desktop/oclc/marcxml/other/"),
file:create-dir($mqy:STEM||"/Desktop/oclc/marcxml/filtered/"),
file:create-dir($mqy:STEM||"/Desktop/oclc/marcxml/raw/"),
file:create-dir($mqy:STEM||"/Desktop/oclc/marc21/")