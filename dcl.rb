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
 DCLNAME = File.join( PATH, "dcl" )          # hard-wire this name...
LINKPATH = File.join( PATH, "dcllinks" )     # symlinks go here...

PROGNAME = File.basename( DCLNAME ).upcase   # not "$0" here!...
  PROGID = "#{PROGNAME} v5.1 (08/21/2015)"
  AUTHOR = "Lorin Ricker, Elbert, Colorado, USA"

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
# CREATE:touch, DIRECTORY:ls,
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
#   %dcl-S-created, symlink ~/bin/dcllinks/capcase created
#   %dcl-S-created, symlink ~/bin/dcllinks/locase created

# The --symlinks (-s) option checks &/or verifies each function in FNC_LINKS
# (including itself), and either creates a symlink to the dcl script if it does
# not (yet) exist, or complains with an error message if a previous (ordinary)
# file by that name already exists.
#
# The dcl --symlinks option serves as an installation bootstrap step, as well
# as a periodic &/or troubleshooting verification step; e.g.:
#
#   $ dcl [--verbose] --symlinks   # verify &/or install all function symlinks
#   %dcl-S-created, symlink ~/bin/dcllinks/capcase created
#   %dcl-S-verified, symlink ~/bin/dcllinks/collapse verified
#   %dcl-S-verified, symlink ~/bin/dcllinks/compress verified
#   ...
#   %dcl-S-created, symlink ~/bin/dclsymlink created

require 'optparse'
require 'pp'
require_relative 'lib/DCLcommand'
require_relative 'lib/DCLfunction'
require_relative 'lib/FileEnhancements'
require_relative 'lib/ANSIseq'

# ==========

def help_available( tag, links, perline )
  hlp    = tag
  hlplen = hlp.length
  i      = 0
  links.each do | c |  # concatenate c ,-sep & measured list of commands
    i   += 1
    hlp += c
    hlp += ", " if i < links.size
    hlp += "\n" + " "*hlplen if i % perline == 0 && i < links.size
  end  # links.each
  puts "\n#{hlp}"
end  # help_available

# ==========

def dclSymlink( syms )
  dn = "-> #{DCLNAME}"
  FileUtils.mkdir_p( LINKPATH ) if ! File.exists?( LINKPATH )
  syms.each do |s|
    slnk = File.join( LINKPATH, s )
    if File.symlink?( slnk )
      # See http://ruby.runpaint.org/ref/file for documentation of new methods
      # File.readlink (used here) and File.realpath...
      if File.readlink( slnk ) == DCLNAME
        $stderr.puts "%#{PROGNAME}-I-verified, symlink #{slnk} is verified (#{dn})".color(:green)
      else
        $stderr.puts "%#{PROGNAME}-E-badlink,  symlink #{slnk} is wrong (not #{dn})".color(:red)
      end  # if File.identical?( DCLNAME, slnk )
    else
      if ! File.file?( slnk )  # no ordinary file collision?
        File.symlink( DCLNAME, slnk )
        $stderr.puts "%#{PROGNAME}-S-created,  symlink #{slnk} created (#{dn})".color(:blue)
      else
        $stderr.puts "%#{PROGNAME}-E-conflict, file #{slnk} exists, no symlink created".color(:red)
      end  # if ! File.file?( slnk )
    end  # if File.symlink( slnk )
  end  # syms.each
end  # dclSymlink

# ==========

                # See also dclrename.rb; "set" conflicts with bash 'set' command
CMD_LINKS = %w{ copy create
                delete directory
                rename
                search show }  # removed 'purge' as likely never to be implemented
FNC_LINKS = %w{ locase lowercase
                upcase uppercase
                capcase titlecase
                collapse compress
                cjust ljust rjust
                fao sprintf
                edit element extract substr
                length pluralize
                thousands numbernames
                trim trim_leading trim_trailing
                uncomment
                dclsymlink }
ALL_LINKS = CMD_LINKS + FNC_LINKS

options = { :confirm     => false,
            :pager       => false,
            :preserve    => false,
            :links       => false,
            :noop        => false,
            :force       => false,
            :verbose     => false,
            :debug       => DBGLVL0,
            :about       => false
          }

ARGV[0] = '--help' if ARGV.size == 0  # force help if naked command-line

optparse = OptionParser.new { |opts|
  opts.on( "-F", "--force",
           "Force rename to replace existing files" ) do |val|
    options[:force] = true
  end  # -F --force
  opts.on( "-n", "--noop", "--dryrun", "--test",
           "Dry-run (test & display, no-op) mode" ) do |val|
    options[:noop]  = true
  end  # -n --noop
  opts.on( "-i", "--interactive", "--confirm",
           "Interactive mode (/CONFIRM)" ) do |val|
    options[:confirm] = true
  end  # -i --interactive --confirm
  opts.on( "-m", "--pager", "--less", "--more",
           "Use pager (less) for long output (/PAGE)" ) do |val|
    options[:pager] = true
  end  # -m --pager
  opts.on( "-p", "--preserve",
           "Preserves file metadata",
           "  (owner, permissions, datetimes)" ) do |val|
    options[:preserve] = true
  end  # -p --preserve
  # --- Verbose option ---
  opts.on( "-v", "--verbose", "--log", "Verbose mode (/LOG)" ) do |val|
    options[:verbose] = true
  end  # -v --verbose
  # --- Debug option ---
  opts.on( "-d", "--debug", "=DebugLevel", Integer,
           "Show debug information (levels: 1, 2 or 3)",
           "  1 - enables basic debugger information",
           "  2 - enables advanced debugger information",
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
  opts.banner = "\n  Usage: #{PROGNAME} [options] dclfunc"   +
                "\n\n   where dclfunc is the DCL command or" +
                " lexical function to execute.\n\n"
  opts.on_tail( "-?", "-h", "--help", "Display this help text" ) do |val|
    $stdout.puts opts
    help_available( '  Available commands: ', CMD_LINKS, 8 )
    help_available( ' Available functions: ', FNC_LINKS, 6 )
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

action = File.basename( $0 ).downcase  # $0 is name of invoking symlink...

if options[:symlinks]
  dclSymlink( ALL_LINKS )       # set &/or verify ALL_LINKS symlinks
else
  # Dispatch/processing for each sym-linked command begins here...
  if CMD_LINKS.find_index( action )   # one of the Command actions?
  then
    DCLcommand.fileCommands( action, ARGV, options )
  else
    DCLfunction.lexFunctions( action, ARGV, options )
  end
end  # if options[:symlinks]

exit true
