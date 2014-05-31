#Wikipedia benchmark : Rroonga vs SQLite

## Install
  >gem install rroonga  
  >gem install sqlite3  
  >git clone git@github.com:naoa/rroonga-wikipedia-bench  
  >cd rroonga-wikipedia-bench  
  >wget http://download.wikimedia.org/jawiki/latest/jawiki-latest-pages-articles.xml.bz2  
  >bunzip2 jawiki-latest-pages-articles.xml.bz2  
  >mkdir {rroonga_database_dir}  
  >mkdir {sqlite_database_dir}  

## Create database
  >ruby rroonga-create-wikipedia.rb {wikipedia_xml} {rroonga_database_dir}  
  >ruby sqlite3-create-wikipedia.rb {wikipedia_xml} {sqlite_database_dir} 

## Search database
  1. Search top 100 categories.  
  2. Fulltext search title or text by the top 100 categories.  

  >ruby rroonga-wikipedia-searcher.rb {rroonga_database_dir}  
  >ruby sqlite3-wikipedia-searcher.rb {sqlite_database_dir} 

