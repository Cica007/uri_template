# -*- encoding : utf-8 -*-
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the Affero GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    (c) 2011 by Hannes Georg
#

module URITemplate

  # An awesome little helper which helps iterating over a string.
  # Initialize with a regexp and pass a string to :each.
  # It will yield a string or a MatchData
  class RegexpEnumerator
  
    include Enumerable
    
    def initialize(regexp)
      @regexp = regexp
    end
    
    def each(str)
      return Enumerator.new(self,:each,str) unless block_given?
      rest = str
      loop do
        m = @regexp.match(rest)
        if m.nil?
          yield rest
          break
        end
        yield m.pre_match if m.pre_match.size > 0
        yield m
        if m[0].size == 0
          # obviously matches empty string, so post_match will equal rest
          # terminate or this will loop forever
          yield m.post_match
          break
        end
        rest = m.post_match
      end
      return self
    end
  
  end

  # This error will be raised whenever an object could not be converted to a param string.
  class Unconvertable < StandardError
  
    attr_reader :object
  
    def initialize(object)
      @object = object
      super("Could not convert the given object (#{Object.instance_method(:inspect).bind(@object).call() rescue '<????>'}) to a param since it doesn't respond to :to_param or :to_s.")
    end
  
  end

  # A collection of some utility methods
  module Utils
  
    KCODE_UTF8 = (Regexp::KCODE_UTF8 rescue 0)
  
    # @private
    PCT = /%(\h\h)/.freeze
    
    # A regexp which match all non-simple characters.
    NOT_SIMPLE_CHARS = /([^A-Za-z0-9\-\._])/.freeze
    
    # Encodes the given string into a pct-encoded string.
    # @param s The string to be encoded.
    # @param m A regexp matching all characters, which need to be encoded.
    #
    # @example
    #   URITemplate::Utils.pct("abc") #=> "abc"
    #   URITemplate::Utils.pct("%") #=> "%25"
    #
    #TODO: is encoding as utf8/ascii really needed?
    def pct(s, m=NOT_SIMPLE_CHARS)
      s.to_s.gsub(m){
        '%'+$1.unpack('H2'*$1.bytesize).join('%').upcase
      }.force_encoding('ASCII')
    end
    
    # Decodes the given pct-encoded string into a utf-8 string.
    # Should be the opposite of #pct.
    #
    # @example
    #   URITemplate::Utils.dpct("abc") #=> "abc"
    #   URITemplate::Utils.dpct("%25") #=> "%"
    #
    def dpct(s)
      s.to_s.gsub(PCT){
        $1.to_i(16).chr
      }.force_encoding('UTF-8')
    end
    
    # Converts an object to a param value.
    # Tries to call :to_param and then :to_s on that object.
    # @raise Unconvertable if the object could not be converted.
    # @example
    #   URITemplate::Utils.object_to_param(5) #=> "5"
    #   o = Object.new
    #   def o.to_param
    #     "42"
    #   end
    #   URITemplate::Utils.object_to_param(o) #=> "42"
    def object_to_param(object)
      if object.respond_to? :to_param
        object.to_param
      elsif object.respond_to? :to_s
        object.to_s
      else
        raise Unconvertable.new(object) 
      end
    rescue NoMethodError
      raise Unconvertable.new(object)
    end
    
    
    # Returns true when the given value is an array and it only consists of arrays with two items.
    # This useful when using a hash is not ideal, since it doesn't allow duplicate keys.
    # @example
    #   URITemplate::Utils.pair_array?( Object.new ) #=> false
    #   URITemplate::Utils.pair_array?( [] ) #=> true
    #   URITemplate::Utils.pair_array?( [1,2,3] ) #=> false
    #   URITemplate::Utils.pair_array?( [ ['a',1],['b',2],['c',3] ] ) #=> true
    #   URITemplate::Utils.pair_array?( [ ['a',1],['b',2],['c',3],[] ] ) #=> false
    def pair_array?(a)
      return false unless a.kind_of? Array
      return a.all?{|p| p.kind_of? Array and p.size == 2 }
    end

    # Turns the given value into a hash if it is an array of pairs.
    # Otherwise it returns the value.
    # You can test whether a value will be converted with {#pair_array?}.
    #
    # @example
    #   URITemplate::Utils.pair_array_to_hash( 'x' ) #=> 'x'
    #   URITemplate::Utils.pair_array_to_hash( [ ['a',1],['b',2],['c',3] ] ) #=> {'a'=>1,'b'=>2,'c'=>3}
    #   URITemplate::Utils.pair_array_to_hash( [ ['a',1],['a',2],['a',3] ] ) #=> {'a'=>3}
    #
    # @example Carful vs. Ignorant
    #   URITemplate::Utils.pair_array_to_hash( [ ['a',1],'foo','bar'], false ) #=> {'a'=>1,'foo'=>'bar'}
    #   URITemplate::Utils.pair_array_to_hash( [ ['a',1],'foo','bar'], true ) #=> [ ['a',1],'foo','bar']
    #
    # @param x the value to convert
    # @param careful [true,false] wheter to check every array item. Use this when you expect array with subarrays which are not pairs. Setting this to false however improves runtime by ~30% even with comparetivly short arrays.
    def pair_array_to_hash(x, careful = false )
      if careful ? pair_array?(x) : (x.kind_of?(Array) and x.first.kind_of?(Array))
        return Hash[ *x.flatten(1) ]
      else
        return x
      end
    end
    
    extend self
  
  end

end
