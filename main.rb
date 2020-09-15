# coding: utf-8
class InvalidTokenError < StandardError
end
class NullToken
end

class Token
  attr_reader :type, :value
  def initialize(type:, value:)
    @type = type
    @value = value
    raise InvalidTokenError if value.nil? || type.nil?
  end
  def null
    NullToken.new
  end
  def null?
    false
  end
  def length
    value.length
  end
  def self.end_of_file
    Token.new(type: 'EOF', value: '')
  end
  def present?
    true
  end

  def to_s
    "<type: #{type}, value: #{value}>"
  end
end

class SimpleScanner
  TOKEN_TYPES = {
    '_'  => 'UNDERSCORE',
    '*'  => 'STAR',
    "\n" => 'NEWLINE',
    " " => 'EMPTY',
    "#" => 'H1',
    "##" => 'H2',
    "###" => 'H3',
    "####" => 'H4',
    "#####" => 'H5',
  }.freeze

  def self.from_string(plain_markdown)
    char = plain_markdown[0]
    Token.new(type: TOKEN_TYPES[char], value: char)
  rescue InvalidTokenError
    nil
  end
end

class TextScanner < SimpleScanner
  def self.from_string(plain_markdown)
    text = plain_markdown
             .each_char
             .take_while { |char| SimpleScanner.from_string(char).nil? }
             .join('')
    Token.new(type: 'TEXT', value: text)
  rescue InvalidTokenError
    Token.null
  end
end

class HTree
  attr_accessor :node, :children, :contents, :last_htree, :parent
  def initialize(node:)
    @node = node
    @children = []
    @contents = []
    @last_htree = self
  end
  def append(tree)
    unless tree.node.type.match(/^H[1-5]$/)
      @last_htree.contents.push(tree.node)
      return
    end
    if @last_htree != self && @last_htree.node.type[1].to_i < tree.node.type[1].to_i
      @last_htree.append(tree)
      tree.parent = tree
    elsif @parent && @parent.node.type[1].to_i > tree.node.type[1].to_i
      @parent.append(tree)
    else
      @children.push(tree)
    end
    @last_htree = tree
  end
  def to_s(tab=0)
    fst_value = ""
    fst_value = @contents[1].value if @contents.size > 0
    puts "#{'#'*tab}#{@node.type} #{fst_value}"
    @contents[2..-1].each{|x| puts "#{'-'*tab}=>#{x.value}"} if @contents.size > 0
    @children.each{|x| x.to_s(tab+1)} if @children.size > 0
  end
end

class Tokenizer
  TOKEN_SCANNERS = [
    SimpleScanner,
    TextScanner
  ].freeze

  def tokenize_htree(plain_markdown)
    tk_ary = tokenize(plain_markdown)
    top_tree = HTree.new(node: Token.new(type: 'H0', value: ''))
    tk_ary.each do |x|
      top_tree.append(HTree.new(node: x))
    end
    top_tree
  end

  def tokenize(plain_markdown)
    tk_ary = tokens_as_array(plain_markdown)
    cnt = 0
    base_cmd = nil
    base_cmd_cnt = 0
    new_ary = []
    while cnt < tk_ary.size
      if (cnt <= 0 || tk_ary[cnt-1].type == 'NEWLINE') && tk_ary[cnt].type == 'H1'
        base_cmd = tk_ary[cnt]
        base_cmd_cnt += 1
      elsif base_cmd && base_cmd.type == tk_ary[cnt].type
        base_cmd_cnt += 1
      elsif base_cmd && tk_ary[cnt].type == 'EMPTY'
        new_ary.push(Token.new(type: "H#{base_cmd_cnt}", value: ('#' * base_cmd_cnt)))
        new_ary.push(tk_ary[cnt])
        base_cmd_cnt = 0
        base_cmd = nil
      else
        if base_cmd
          base_cmd_cnt.times do |i|
            new_ary.push(tk_ary[cnt-1])
          end
          base_cmd_cnt = 0
          base_cmd = nil
        end
        new_ary.push(tk_ary[cnt])
      end
      cnt += 1
    end
    new_ary
  end

  private

  def tokens_as_array(plain_markdown)
    if plain_markdown.nil? || plain_markdown == ''
      [Token.end_of_file]
    else
      token = scan_one_token(plain_markdown)
      [token] + tokens_as_array(plain_markdown[token.length..-1])
    end
  end

  def scan_one_token(plain_markdown)
    TOKEN_SCANNERS.each do |scanner|
      token = scanner.from_string(plain_markdown)
      return token unless token.nil?
    end
    raise "The scanners could not match the given input: #{plain_markdown}"
  end
end

ARGV[1..-1].each do |fp|
  p fp
  tk = Tokenizer.new.tokenize_htree(File.read(fp))
  puts tk
end
