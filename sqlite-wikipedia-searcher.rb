# -*- coding: utf-8 -*-

require 'sqlite3'

class WikipediaSearcher
  def initialize(db_path)
    @db_path = db_path
    @db = SQLite3::Database.open("#{@db_path}/db")
  end

  def database_close
    @db.close
  end

  def top_category(limit)
    puts "================================================"
    puts "top categories"
    puts "------------------------------------------------"
    start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

    sql = "SELECT c.category AS category, COUNT(c.category) AS nsubrecs FROM Wikipedia AS w INNER JOIN Wikipedia_categories AS c ON W.id = c.id GROUP BY c.category ORDER BY nsubrecs DESC LIMIT #{limit};"
    @db.results_as_hash = true
    result = @db.execute(sql)
    result.each do |record|
      puts "#{record['category']}:#{record['nsubrecs']}"
    end

    if result.count > limit
      nhits = limit
    else
      nhits = result.count
    end

    end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    puts "------------------------------------------------"
    puts "#{nhits} hits (#{end_time - start_time} msec)"
    puts "================================================"

    return result
  end

  def search(query)
    puts "match record = #{query}"
    puts "------------------------------------------------"
    puts "        id:title"
    puts "------------------------------------------------"
    start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

    sql = "SELECT id,title FROM Wikipedia AS w WHERE title LIKE '%#{query}%' OR text LIKE '%#{query}%' LIMIT 5;"
    result = @db.execute(sql)

    result.each do |record|
      printf("%10d:%s\n",record['id'],record['title'])
    end

    end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    puts "------------------------------------------------"
    puts "#{result.count} hits (#{end_time - start_time} msec)"
    puts "================================================"
  end

end

if __FILE__ == $0
  searcher = WikipediaSearcher.new(ARGV[0])
  drilldown_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
  n_category = 100
  top_categories = searcher.top_category(n_category)

  drilldown_end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
  drilldown_time_msec = drilldown_end_time - drilldown_start_time
  drilldown_time_sec = drilldown_time_msec / 1000.0

  if top_categories.count < n_category
    n_category = top_categories.counts
  end

  if ARGV[1] != "-c"
    search_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    top_categories.each do |record|
      searcher.search(record['category'])
    end
    search_end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

    search_time_msec = search_end_time - search_start_time
    search_time_sec = search_time_msec / 1000.0
    search_average_time_msec = search_time_msec / n_category
    search_average_time_sec = search_average_time_msec / 1000.0

    puts "drilldown total time : #{drilldown_time_msec} msec (#{drilldown_time_sec} sec)"
    puts "search total time : #{search_time_msec} msec (#{search_time_sec} sec)"
    puts "search average time : #{search_average_time_msec} msec (#{search_average_time_sec} sec)"
  end
  searcher.database_close

end
