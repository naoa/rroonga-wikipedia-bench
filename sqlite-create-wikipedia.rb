# -*- coding: utf-8 -*-
# Wikipedia data: http://download.wikimedia.org/jawiki/latest/jawiki-latest-pages-articles.xml.bz2

require 'sqlite3'
require 'rexml/streamlistener'
require 'rexml/parsers/baseparser'
require 'rexml/parsers/streamparser'

class WikipediaConvertLoader
  def initialize(db_path,input)
    @input = input
    @db_path = db_path
    @db = nil
  end

  def convert(output)
    listener = Listener.new(output,@db)
    catch do |tag|
      parser = REXML::Parsers::StreamParser.new(@input, listener)
      parser.parse
    end
  end

  class Listener
    include REXML::StreamListener

    def initialize(output,db)
      @output = output
      @text_stack = [""]
      @n_records = 0
      @db = db
    end

    def tag_start(name, attributes)
      push_stacks
      case name
      when "page"
        @page = Page.new
      end
    end

    def tag_end(name)
      case name
      when "page"
        # Converted data adds to sqlite table
        @output.puts("#{@page.id}:#{@page.title}")
        sql = "INSERT INTO Wikipedia VALUES('#{@page.id}','#{@page.title}','#{@page.text}')"
        @db.execute_batch(sql)

        @page.extract_categories.each do |category|
          sql = "INSERT INTO Wikipedia_categories VALUES('#{@page.id}','#{category}')"
          @db.execute_batch(sql)
        end

        @n_records += 1
      when "title"
        @page.title = @text_stack.last
      when "id"
        @page.id ||= Integer(@text_stack.last)
      when "text"
        @page.text = @text_stack.last
      end
      pop_stacks
    end

    def text(data)
      @text_stack.last << data
    end

    def cdata(content)
      @text_stack.last << content
    end

    private
    def push_stacks
      @text_stack << ""
    end

    def pop_stacks
      @text_stack.pop
    end

    class Page
      attr_accessor :id, :title, :text
      def initialize
          @id = nil
          @title = nil
          @text = nil
        end

        def extract_categories
          return [] if @text.nil?

          categories = []
          @text.scan(/\[\[(.+?)\]\]/) do |link,|
            case link
            when /\ACategory:(.+?)(?:\|.*)?\z/
              categories << $1
            end
          end
          categories
        end
      end
  end

  def database_create_or_open
    if File.exists?("#{@db_path}/db")
      @db = SQLite3::Database.open("#{@db_path}/db")
    else
      @db = SQLite3::Database.new("#{@db_path}/db")
    end
  end

  def database_close
    @db.close
  end

  def data_table_create
    sql = <<SQL
CREATE TABLE Wikipedia (
 id INTEGER PRIMARY KEY NOT NULL,
 title TEXT,
 text LONG_TEXT
);
CREATE TABLE Wikipedia_categories (
 id INTEGER,
 category TEXT
);
CREATE INDEX category_index ON Wikipedia_categories(id,category);
SQL
    @db.execute_batch(sql)
  end


end

if __FILE__ == $0
  # ARGV[0]:Wikipedia XML file path
  # ARGV[1]:SQLite database "directory" path

  # Create database and table
  loader = WikipediaConvertLoader.new(ARGV[1],File.open(ARGV[0]))
  loader.database_create_or_open
  loader.data_table_create

  # XML convert & load data
  load_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
  output = $stdout
  loader.convert(output)
  load_end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

  loader.database_close

  puts "======================================================="

  load_time_msec = load_end_time - load_start_time
  load_time_sec = load_time_msec / 1000

  puts "XML convert & load time : #{load_time_msec} msec (#{load_time_sec} sec)"

end
