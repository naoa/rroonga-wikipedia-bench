#Wikipedia benchmark : Rroonga vs SQLite

# Install
  >gem install rroonga  
  >gem install sqlite3  
  >git clone git@github.com:naoa/rroonga-wikipedia-bench

## Create database
  >ruby rroonga-create-wikipedia.rb {wikipedia_xml} {database_dir}  
  >ruby sqlite3-create-wikipedia.rb {wikipedia_xml} {database_dir} 

## Search database
  1. Search top 100 categories.  
  2. Fulltext search title or text by the top 100 categories.  

  >ruby rroonga-wikipedia-searcher.rb {database_dir}  
  >ruby sqlite3-wikipedia-searcher.rb {database_dir} 

