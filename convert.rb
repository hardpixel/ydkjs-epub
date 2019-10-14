require 'ostruct'
require 'fileutils'

CUR_DIR = File.expand_path(__dir__)
SRC_DIR = File.expand_path('.source', __dir__)
OUT_DIR = File.expand_path('books', __dir__)

class Inflector
  attr_reader :text, :words

  MAPPINGS = { js: 'JS', es: 'ES', es6: 'ES6' }.freeze

  def self.titleize(text)
    new(text).titleize
  end

  def initialize(text)
    @text  = normalize(text)
    @words = @text.split(' ')
  end

  def titleize
    parts = words.map do |word|
      MAPPINGS.fetch(word.to_sym, word.capitalize)
    end

    parts.join(' ')
  end

  private

  def normalize(string)
    string.gsub(/-|_/, ' ').downcase.strip
  end
end

class Files
  attr_reader :path

  def self.folders(path)
    new(path).entries do |file|
      File.directory?(file)
    end
  end

  def self.files(path)
    new(path).entries do |file|
      !File.directory?(file)
    end
  end

  def self.named(name, files)
    files.find { |file| file.name == name }
  end

  def self.prefixed(prefix, files)
    objects = files.select do |file|
      file.name.start_with?(prefix)
    end

    objects.sort_by(&:name)
  end

  def initialize(path)
    @path = path
  end

  def entries
    Dir.entries(path).each_with_object([]) do |file, files|
      next if file.start_with?('.')

      fpath  = File.join(path, file)
      fext   = file.split('.').last
      fname  = file.sub(/\.\w+{2,3}/, '')
      struct = OpenStruct.new(name: fname, path: fpath, ext: fext)

      files << struct if yield(fpath)
    end
  end
end

class Book
  attr_reader :name, :path, :preface, :author, :branch

  def initialize(name:, path:, preface:, author:, branch:)
    @name    = name
    @path    = path
    @preface = preface
    @author  = author
    @branch  = branch
  end

  def pathname
    path.split('/').last
  end

  def title
    "#{name}: #{Inflector.titleize(pathname)}"
  end

  def filename
    "#{title}.epub"
  end

  def styles
    File.join(CUR_DIR, 'epub.css')
  end

  def output
    File.join(OUT_DIR, branch, filename)
  end

  def files
    @files ||= Files.files(path)
  end

  def chapters
    @chapters ||= Files.prefixed('ch', files)
  end

  def appendixes
    @appendixes ||= Files.prefixed('ap', files)
  end

  def foreword
    @foreword ||= Files.named('foreword', files)
  end

  def cover
    @cover ||= begin
      file = Files.named('cover', files)
      file&.path || File.expand_path('cover.jpg', CUR_DIR)
    end
  end

  def pages
    [foreword, preface, chapters, appendixes].flatten.compact
  end

  def metadata
    { author: author, title: title }
  end

  def options
    {
      '--read'             => 'markdown+smart',
      '--output'           => output,
      '--css'              => styles,
      '--highlight-style'  => 'tango',
      '--epub-cover-image' => cover
    }
  end

  def generate
    data = pages.map { |file| "'#{file.path}'" }.join(' ')
    meta = metadata.transform_keys { |key| "-M #{key}" }
    opts = options.merge(meta).map { |key, value| "#{key}='#{value}'" }.join(' ')

    FileUtils.chdir(path) do
      system("pandoc #{opts} #{data}")
    end
  end
end

class Generator
  attr_reader :github, :branch, :author

  def self.call(**options)
    new(**options).call
  end

  def initialize(github:, branch:, author:)
    @github = github
    @branch = branch
    @author = author
  end

  def repo
    "https://github.com/#{github}.git"
  end

  def name
    Inflector.titleize(github.split('/').last)
  end

  def folders
    @folders ||= Files.folders(SRC_DIR)
  end

  def files
    @files ||= Files.files(SRC_DIR)
  end

  def books
    @books ||= folders.map do |file|
      Book.new(
        name: name,
        path: file.path,
        preface: preface,
        author: author,
        branch: branch
      )
    end
  end

  def preface
    @preface ||= Files.named('preface', files)
  end

  def output
    File.join(OUT_DIR, branch)
  end

  def call
    cleanup
    clone
    generate
    cleanup
  end

  private

  def clone
    puts "==> Cloning repository\n\n"
    system("git clone --single-branch --branch #{branch} #{repo} #{SRC_DIR}")

    FileUtils.chdir(SRC_DIR) do
      puts "\n"
      system("sh #{File.expand_path('cleanup.sh', CUR_DIR)}")
    end
  end

  def cleanup
    if File.exists?(SRC_DIR)
      puts "--> Cleaning build files\n"
      FileUtils.rm_rf(SRC_DIR)
    end
  end

  def generate
    puts "==> Generating books\n"

    FileUtils.mkdir_p(output)
    books.each(&:generate)
  end
end

Generator.call(
  github: 'getify/You-Dont-Know-JS',
  branch: '1st-ed',
  author: 'Kyle Simpson'
)

Generator.call(
  github: 'getify/You-Dont-Know-JS',
  branch: '2nd-ed',
  author: 'Kyle Simpson'
)
