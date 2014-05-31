# -*- coding: utf-8 -*-
# Wikipedia data: http://download.wikimedia.org/jawiki/latest/jawiki-latest-pages-articles.xml.bz2

# Note:This programmed by reference to the https://github.com/droonga/wikipedia-search/blob/master/lib/groonga-converter.rb
# Thanks kou!

require 'groonga'
require 'rexml/streamlistener'
require 'rexml/parsers/baseparser'
require 'rexml/parsers/streamparser'

class WikipediaConvertLoader
  def initialize(input)
    @input = input
  end

  def convert(output)
    listener = Listener.new(output)
    catch do |tag|
      parser = REXML::Parsers::StreamParser.new(@input, listener)
      parser.parse
    end
  end

  class Listener
    include REXML::StreamListener

    def initialize(output)
      @output = output
      @text_stack = [""]
      @n_records = 0
      @table = Groonga["Wikipedia"]
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
        # If you want to output json text
        # page = {
        #   "_key" => @page.id,
        #   "title" => @page.title,
        #   "text" => @page.text,
        #   "categories" => @page.extract_categories,
        # }
        # @output.print(JSON.generate(page))

        # Converted data adds to Groonga table
        @output.puts("#{@page.id}:#{@page.title}")
        @table.add(@page.id,
                  :title => @page.title,
                  :text => @page.text,
                  :categories => @page.extract_categories)

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
end

class WikipediaSchemaBuilder
  def initialize(db_path)
    @db_path = db_path
  end

  def database_create_or_open
    if File.exists?("#{@db_path}/db")
      Groonga::Database.open("#{@db_path}/db")
    else
      Groonga::Database.create(:path => "#{@db_path}/db")
    end
  end

  def data_table_create
    Groonga::Schema.define do |schema|
      schema.create_table("Wikipedia-categories",
                          :type => :hash,
                          :key_type => :short_text) do |table|
      end

      schema.create_table("Wikipedia",
                          :type => :hash,
                          :key_type => :unsigned_integer64) do |table|
        table.short_text("title")
        table.long_text("text")
        table.reference("categories", "Wikipedia-categories", :type => :vector)
      end

      schema.change_table("Wikipedia-categories") do |table|
        table.index("Wikipedia.categories")
      end

    end
  end

  def lexicon_table_create
    Groonga::Schema.define do |schema|
      schema.create_table("Wikipedia-lexicon",
                          :type => :patricia_trie,
                          :key_type => :short_text,
                          :normalizer => "NormalizerAuto",
                          :default_tokenizer => "TokenBigram") do |table|
        table.index("Wikipedia.title")
        table.index("Wikipedia.text")
      end
    end
  end

  def data_table_remove
    Groonga::Schema.define do |schema|
      schema.remove_table("Wikipedia")
      schema.remove_table("Wikipedia-categories")
    end
  end

  def lexicon_table_remove
    Groonga::Schema.define do |schema|
      schema.remove_table("Wikipedia-lexicon")
    end
  end

end

if __FILE__ == $0
  # ARGV[0]:Wikipedia XML file path
  # ARGV[1]:Groonga database "directory" path

  # Create database and table
  schemabuilder = WikipediaSchemaBuilder.new(ARGV[1])
  schemabuilder.database_create_or_open
  schemabuilder.data_table_create

  # If you want to use online index construction by create indexes
  # schemabuilder.lexicon_table_create

  # XML convert & load data
  load_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
  loader = WikipediaConvertLoader.new(File.open(ARGV[0]))
  output = $stdout
  loader.convert(output)
  load_end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

  # Use offline index construction by create indexes
  index_start_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}
  schemabuilder.lexicon_table_create
  index_end_time = Time.now.instance_eval { self.to_i * 1000 + (usec/1000)}

  puts "======================================================="

  load_time_msec = load_end_time - load_start_time
  load_time_sec = load_time_msec / 1000

  puts "XML convert & load time : #{load_time_msec} msec (#{load_time_sec} sec)"

  index_time_msec = index_end_time - index_start_time
  index_time_sec = index_time_msec / 1000

  puts "Index time : #{index_time_msec} msec (#{index_time_sec} sec)"

end
