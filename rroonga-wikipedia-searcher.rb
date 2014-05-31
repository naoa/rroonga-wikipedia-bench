# -*- coding: utf-8 -*-

require 'groonga'

class WikipediaSearcher
  def initialize(db_path)
    Groonga::Database.open("#{db_path}/db")
    @table = Groonga['Wikipedia']
  end

  def top_category(limit)
    puts "================================================"
    puts "top categories"
    puts "------------------------------------------------"
    start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

    result = @table.select
    grouped = result.group("categories")
    grouped = grouped.sort([{:key => "_nsubrecs",:order => "descending"}])
    grouped.each({:limit => limit}) do |category|
      puts "#{category._key}:#{category._nsubrecs}"
    end

    if grouped.size > limit
      nhits = limit
    else
      nhits = grouped.size
    end

    end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    puts "------------------------------------------------"
    puts "#{nhits} hits (#{end_time - start_time} msec)"
    puts "================================================"

    return grouped
  end

  def search(query)
    puts "match record = #{query}"
    puts "------------------------------------------------"
    puts "        id:title"
    puts "------------------------------------------------"
    start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

    result = @table.select do |record|
      record.match(query) do |match_record|
        (match_record.title * 100)| match_record.text
      end
    end

    result.each({:limit => 5}) do |record|
      printf("%10d:%s\n",record._key,record.title)
    end

    end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    puts "------------------------------------------------"
    puts "#{result.size} hits (#{end_time - start_time} msec)"
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

  if top_categories.size < n_category
    n_category = top_categories.size
  end

  if ARGV[1] != "-c"
    search_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
    top_categories.each({:limit => n_category}) do |category|
      searcher.search(category._key)
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

end
