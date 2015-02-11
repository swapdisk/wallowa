#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# dcl.rb
#
# Copyright © 2012-2015 Lorin Ricker <Lorin@RickerNet.us>
# Version info: see PROGID below...
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.

# -----

    PATH = File.dirname $0
 DCLNAME = File.join( PATH, "DCL" ).downcase    # hard-wire this name...
      DN = "-> #{DCLNAME}"
PROGNAME = File.basename DCLNAME                # not "$0" here!...
  PROGID = "#{PROGNAME} v2.3 (02/11/2015)"
  AUTHOR = "Lorin Ricker, Castle Rock, Colorado, USA"

   CONFIGDIR = File.join( ENV['HOME'], ".config", PROGNAME )
  CONFIGFILE = File.join( CONFIGDIR, ".#{PROGNAME}.yaml.rc" )

# -----

DBGLVL0 = 0
DBGLVL1 = 1
DBGLVL2 = 2  ######################################################
DBGLVL3 = 3  # <-- reserved for binding.pry &/or pry-{byebug|nav} #
             ######################################################
# ==========

# dcl is an emulator environment for selected VMS (OpenVMS) DCL commands
# and lexical functions. It provides a transitional working environment
# between VMS and Linux command line syntaxes, while also providing
# extended com-line lexical functions borrowed from VMS into Linux.

# dcl is extended (v2.xx) to provide DCL file operation command emulations
# for several common file commands:
# COPY:cp, DELETE:rm, RENAME:mv,
# CREATE:touch, PURGE:??, DIRECTORY:ls,
# SEARCH:grep, SHOW:set.

# dcl provides command line (shell) access to a small library of string-
# transformational routines which are reminiscent of those found in the
# VMS/DCL repertory of F$* functions, callable as if these were bash
# "built-in" functions (v1.xx).

# Access (calls) to these functions are implemented by creating named symlinks
# for each function; these symlinks point (refer to) this dcl script itself,
# such that Ruby's $0 variable (the name of the command/file reference which
# invoked this script invocation) can dispatch execution-control to the correct
# String class method.

# Input for each function comes either from:
#
#   1) The concatenation of all non-switch (non-option) arguments on the
#      command line, joined into a single space-separated string argument.
#      For example, the string-argument for: $ upcase this "is a  " test
#      is: "this is a   test"
#
#   2) Standard Input, if there is/are no non-switch options provided on
#      the command line.

# Output from the function is written to Standard Output with no further
# embellishments or decorations (i.e., no surrounding quotations, etc.).
# For example, the output from the sample upcase function call given in 1)
# above would be: THIS IS A   TEST

# The --verbose (-v) option is for testing &/or verification of input/output
# results: thus this command will output three lines, the echoed command line,
# the annotated result, and the pure result line itself:
#
#   $ upcase -v "this is a test"
#   %upcase-I-echo,   $ upcase 'this is a test'
#   %upcase-I-result, 'THIS IS A TEST'
#   THIS IS A TEST

# Function results can be captured/assigned to a bash variable thusly:
#
#   $ var=$( upcase "this is a test" )
#   $ echo $var
#   THIS IS A TEST

# This mechanism also provides for functional results to be applied via a pipe:
#
#   $ var=$( compress "  this   is a test   " | upcase )
#   $ echo $var
#   THIS IS A TEST

# Intermediate results can be checked/tracked with --verbose:
#
#   var=$( compress -v "   this is a      test   " | upcase -v )
#   %compress-I-echo,   $ compress '   this is a      test   '
#   %compress-I-result, 'this is a test'
#   %upcase-I-echo,   $ upcase 'this is a test'
#   %upcase-I-result, 'THIS IS A TEST'
#   $ echo $var
#   THIS IS A TEST

# One function, edit, allows a list of edits to be applied to the argument
# string, which is an alternative way to the pipe-method above to execute
# a sequence of functional filters:
#
#   $ edit -v "compress,upcase" "   this is a      test   "
#   %dcl-I-echo,   $ edit '   this is a      test   '
#   %dcl-I-result, 'THIS IS A TEST'
#   THIS IS A TEST

# One dcl function is special: dclsymlink -- This function checks and verifies
# each of its arguments, which name function symlink(s): it does for each named
# function(s) what the --symlinks option (below) does for all functions.
#
#   $ dclsymlink capcase locase [...]
#   %dcl-S-created, symlink ~/bin/capcase created
#   %dcl-S-created, symlink ~/bin/locase created

# The --symlinks (-s) option checks &/or verifies each function in FNC_LINKS
# (including itself), and either creates a symlink to the dcl script if it does
# not (yet) exist, or complains with an error message if a previous (ordinary)
# file by that name already exists.
#
# The dcl --symlinks option serves as an installation bootstrap step, as well
# as a periodic &/or troubleshooting verification step; e.g.:
#
#   $ dcl [--verbose] --symlinks   # verify &/or install all function symlinks
#   %dcl-S-created, symlink ~/bin/capcase created
#   %dcl-S-verified, symlink ~/bin/collapse verified
#   %dcl-S-verified, symlink ~/bin/compress verified
#   ...
#   %dcl-S-created, symlink ~/bin/dclsymlink created

require 'optparse'
require 'fileutils'
require 'pp'
require_relative 'lib/ppstrnum'
require_relative 'lib/StringEnhancements'
require_relative 'lib/FileEnhancements'
require_relative 'lib/ANSIseq'

# ==========

def bad_fucmd_params( e, debug )
  $stderr.puts "%#{PROGNAME}-e-notdir, destination path must be a directory"
  pp e if debug > DBGLVL0
  exit false
end  # bad_fucmd_params

def help_available( tag, links, perline )
  hlp    = tag
  hlplen = hlp.length
  i      = 0                        # counter
  links.each do | c |  # concatenate c ,-sep & measured list of commands
    i += 1
    hlp += c
    hlp += ", " if i < links.size
    hlp += "\n" + " "*hlplen if i % perline == 0 && i < links.size
  end  # links.each
  puts "\n#{hlp}"
end  # help_available

def dclsymlink( syms )
  syms.each do |s|
    slnk = File.join( PATH, s )
    if File.symlink?( slnk )
      # See http://ruby.runpaint.org/ref/file for documentation of new methods
      # File.readlink (used here) and File.realpath...
      if File.readlink( slnk ) == DCLNAME
        $stderr.puts "%#{PROGNAME}-I-verified, symlink #{slnk} is verified (#{DN})".color(:green)
      else
        $stderr.puts "%#{PROGNAME}-E-badlink,  symlink #{slnk} is wrong (not #{DN})".color(:red)
      end  # if File.identical?( DCLNAME, slnk )
    else
      if ! File.file?( slnk )  # no ordinary file collision?
        File.symlink( DCLNAME, slnk )
        $stderr.puts "%#{PROGNAME}-S-created,  symlink #{slnk} created (#{DN})".color(:blue)
      else
        $stderr.puts "%#{PROGNAME}-E-conflict, file #{slnk} exists, no symlink created".color(:red)
      end  # if ! File.file?( slnk )
    end  # if File.symlink( slnk )
  end  # syms.each
end  # dclsymlink

def getargs( options )
  args = ''
  if ARGV[0]                             # Not: ARGF !=== ARGV.join(" ")
    args = ARGV.join( " " )              # All args into one big sentence...
  else                                   # ...or from std-input
    args = $stdin.readline.chomp if !options[:symlinks]
  end  # if ARGV[0]
  return args
end  # getargs

def parse_dcl_qualifiers( argvector )
  argvl  = argvector.length
  quals  = Hash.new
  fspecs = []
  pat    = /^\/(LOG|CONF[IRM]*)$/i
  argvector.each do | a |
    if pat.match( a )
      # A DCL qualifier /LOG or /CONF[IRM]: record it...
      quals[:verbose] = true if $1 == "log"
      quals[:confirm] = true if $1[0..3] == "conf"
    else
      # A file-spec, copy it...
      fspecs << a
    end
  end
  return case argvl
         when 0 then [ nil,           nil,        quals ]
         when 1 then [ fspecs[0],     nil,        quals ]
         when 2 then [ fspecs[0],     fspecs[1],  quals ]
                else [ fspecs[0..-2], fspecs[-1], quals ]
         end  # case
end  # parse_dcl_qualifiers

def blend( options, quals )
  fuopts = Hash.new
  fuopts[:verbose]  = options[:verbose] || quals[:verbose]
  fuopts[:noop]     = options[:noop]
  fuopts[:preserve] = options[:preserve]
  return fuopts
end  # blend

# ==========

CMD_LINKS = %w{ copy create rename
                delete purge search
                directory show }   # "set" conflicts with bash 'set' command
FNC_LINKS = %w{ capcase locase upcase titlecase
                collapse compress
                cjust ljust rjust
                edit element extract substr
                length pluralize
                thousands numbernames
                trim trim_leading trim_trailing
                uncomment
                dclsymlink }
ALL_LINKS = CMD_LINKS + FNC_LINKS

options = { :interactive => false,
            :noop        => false,
            :pager       => false,
            :preserve    => false,
            :links       => false,
            :verbose     => false,
            :debug       => DBGLVL0,
            :about       => false
          }

optparse = OptionParser.new { |opts|
  opts.on( "-n", "--noop", "--dryrun", "--test",
           "Dry-run (test & display, no-op) mode" ) do |val|
    options[:noop]  = true
    options[:verbose] = true  # Dry-run implies verbose...
  end  # -n --noop
  opts.on( "-i", "--interactive", "--confirm",
           "Interactive mode (/CONFIRM)" ) do |val|
    options[:interactive] = true
  end  # -i --interactive
  opts.on( "-m", "--pager", "--less", "--more",
           "Use pager (less) for long output" ) do |val|
    options[:pager] = true
  end  # -m --pager
  opts.on( "-p", "--preserve",
           "Preserves file metadata (owner, permissions, datetimes)" ) do |val|
    options[:preserve] = true
  end  # -p --preserve
  # --- Verbose option ---
  opts.on( "-v", "--verbose", "--log", "Verbose mode" ) do |val|
    options[:verbose] = true
  end  # -v --verbose
  # --- Debug option ---
  opts.on( "-d", "--debug", "=DebugLevel", Integer,
           "Show debug information (levels: 1, 2 or 3)",
           "  1 - enables basic debugging information",
           "  2 - enables advanced debugging information",
           "  3 - enables (starts) pry-byebug debugger" ) do |val|
    options[:debug] = val.to_i
  end  # -d --debug
  opts.on( "-l", "--links", "--symlinks",
           "Create or verify symlinks for all functions" ) do |val|
    options[:symlinks] = true
  end  # -l --symlinks --links
  # --- About option ---
  opts.on_tail( "-a", "--about", "Display program info" ) do |val|
    $stdout.puts "#{PROGID}"
    $stdout.puts "#{AUTHOR}"
    options[:about] = true
    exit true
  end  # -a --about
  # --- Set the banner & Help option ---
  opts.banner = "\n  Usage: #{PROGNAME} [options] dclfunction"   +
                "\n\n   where dclfunction is the DCL command or lexical function to execute.\n\n"
  opts.on_tail( "-?", "-h", "--help", "Display this help text" ) do |val|
    $stdout.puts opts
    help_available( '  Available commands: ', CMD_LINKS, 8 )
    help_available( ' Available functions: ', FNC_LINKS, 4 )
    options[:help] = true
    exit true
  end  # -? --help
}.parse!  # leave residue-args in ARGV

###############################
if options[:debug] >= DBGLVL3 #
  require 'pry'               #
  binding.pry                 #
end                           #
###############################

## File.check_yaml_dir( CONFIGDIR )
## File.configuration_yaml( «+», «+» )

action = File.basename( $0 ).downcase  # $0 is name of invoking symlink...

if options[:symlinks]
  dclsymlink( ALL_LINKS )       # set &/or verify ALL_LINKS symlinks
  exit true
else
  # Dispatch/processing for each sym-linked command begins here...
  if CMD_LINKS.find( action )   # one of the Command actions?
    src, dst, quals = parse_dcl_qualifiers( ARGV )
    fuoptions = blend( options, quals )
    if options[:debug] >= DBGLVL2
      pp src
      pp dst
      pp quals
      pp fuoptions
    end

    # Commands:
    case action.to_sym
    when :copy
      # See ri FileUtils[::cp]
      begin
        FileUtils.cp( src, dst, fuoptions )
      rescue StandardError => e
        bad_fucmd_params( e, options[:debug] )
      end
    # when :create
    when :rename
      # See ri FileUtils[::mv]
      begin
        FileUtils.mv( src, dst, fuoptions )
      rescue StandardError => e
        bad_fucmd_params( e, options[:debug] )
      end
    when :delete
      # See ri FileUtils[::rm]
      begin
        FileUtils.rm( src, fuoptions )
      rescue StandardError => e
        bad_fucmd_params( e, options[:debug] )
      end
    # when :purge
    # when :directory
    # when :show
    when :search
    # 'SEARCH files pattern' --> 'grep pattern files'
    # This 'SEARCH' command is more powerful than VMS/DCL's, since it uses
    # general regular expressions (regexps) rather than 'simple wildcarded'
    # search-strings...
      cmd = "/bin/grep --color=always --ignore-case -e '#{dst}' "
      src.each { |s| cmd << " '#{s}'" }
      cmd += " | less" if options[:pager]
      exec( cmd )  # chains, no return...
    else
      $stderr.puts "%#{PROGNAME}-e-nyi, DCL command '#{action}' not yet implemented"
      exit false
    end
    exit true

  else
    # Functions:
    case action.to_sym              # Dispatch the command-line action;
                                    # invoking symlink's name is $0 ...
    when :capcase
      args = getargs( options )
      result = args.capcase

    when :collapse
      args = getargs( options )
      result = args.collapse

    when :compress
      args = getargs( options )
      result = args.compress

    when :length
      args = getargs( options )
      result = args.length         # String class does this one directly

    when :locase
      args = getargs( options )
      result = args.locase         # String class does this one directly

    when :numbernames
      # $ numbernames number
      args = getargs( options )
      # Stanza-per-line output:
      #    call as: args.numbernames( '\n' )
      # for use as: $ echo -e $( numbernames <num> )
      result = args.numbernames.split( ', ' )
      result.each { |s| $stdout.puts s }
      exit true

    when :thousands
      # $ thousands number
      args = getargs( options )
      result = args.thousands

    when :titlecase
      args = getargs( options )
      result = args.titlecase

    when :trim
      args = getargs( options )
      result = args.strip          # String class does this one directly

    when :trim_leading
      args = getargs( options )
      result = args.lstrip         # String class does this one directly

    when :trim_trailing
      args = getargs( options )
      result = args.rstrip         # String class does this one directly

    when :uncomment
      args = getargs( options )
      result = args.uncomment

    when :upcase
      args = getargs( options )
      result = args.upcase         # String class does this one directly

    # when :«+»
    #   args = getargs( options )
    #   result = args.«+»

    when :cjust
      # $ cjust width "String to center-justify..."
      ## >> How to default width to terminal-width, and how to specify padchr? Syntax?
      width  = ARGV.shift.to_i
      # padchr = ARGV.shift
      args = getargs( options )
      result = args.center( width )

    when :ljust
      # $ ljust width "String to center-justify..."
      width  = ARGV.shift.to_i
      # padchr = ARGV.shift
      args = getargs( options )
      result = args.ljust( width )

    when :rjust
      # $ rjust width "String to center-justify..."
      width  = ARGV.shift.to_i
      # padchr = ARGV.shift
      args = getargs( options )
      result = args.rjust( width )

    when :edit
      # $ edit "func1,func2[,...]" "String to filter"
      #   where "func1,funct2[,...]" -- the editlist -- is required
      editlist = ARGV.shift            # assign and remove arg [0]
      args = getargs( options )
      result = args.edit( editlist, '#' )  # assume bash-style comments

    when :element
      # $ element 2 [","] "String,to,extract,an,element,from:
      #   where first arg is the element-number (zero-based) to extract,
      #   and second arg is (optional) element separator (default ",");
      #   note that if length of second arg is > 1, it defaults, and
      #   remainder of string is the string to filter
      elem = ARGV.shift.to_i           # assign and remove arg [0]
      sep  = ARGV[0].length == 1 ? ARGV.shift : ","  # and arg [1]
      args = getargs( options )
      result = args.element( elem, sep )

    when :pluralize
      # $ pluralize word howmany [irregular]
      word      = ARGV.shift                  # assign and remove arg [0]
      howmany   = ARGV.shift.to_i             # and arg [1]
      irregular = ARGV[0] ? ARGV.shift : nil  # and (optional) arg [2]
      # args = getargs( options )             # ...ignore rest of com-line
      result = word.pluralize( howmany, irregular )

    when :substr, :extract
      # $ substr start len "String to extract/substring from..."
      start = ARGV.shift.to_i
      len   = ARGV.shift.to_i
      args  = getargs( options )
      result = args[start,len]      # String class does this one directly

    when :dclsymlink
      # $ dclsymlink action [action]...
      dclsymlink( ARGV )            # Set &/or verify this action verb symlink
      exit true

    else
      $stderr.puts "%#{PROGNAME}-e-nyi, DCL function '#{action}' not yet implemented"
      exit false

    end  # case

    if options[:verbose]
      $stderr.puts "%#{PROGNAME}-I-echo,   $ " + "#{action}".underline + " '#{args}'"
      $stderr.puts "%#{PROGNAME}-I-result, " + "'#{result}'".bold
    end  # if options[:verbose]

    $stdout.print result  # Print filtered result to std-output

  end  # case action.to_sym

  exit true

end  # if options[:symlink]
