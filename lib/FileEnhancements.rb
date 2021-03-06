#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# FileEnhancements.rb
#
# Copyright © 2012-2017 Lorin Ricker <Lorin@RickerNet.us>
# Version 1.5, 06/03/2017
#
# This program is free software, under the terms and conditions of the
# GNU General Public License published by the Free Software Foundation.
# See the file 'gpl' distributed within this project directory tree.
#

# Refactored all file-parse related methods to lib/FileParse.rb (06/03/2017)

require 'fileutils'
require 'yaml'
#~ require 'pp'

ONEKILO = 2 ** 10  #                1024
ONEMEGA = 2 ** 20  #             1048576
ONEGIGA = 2 ** 30  #          1073741824
ONETERA = 2 ** 40  #       1099511627776
ONEPETA = 2 ** 50  #    1125899906842624
ONEEXA  = 2 ** 60  # 1152921504606846976

class File

# Some initializing things for owner_human_readable:
# Slurp up /etc/group file into hash { gid => group, ... }
@gids = Hash.new{ "" }
open( "/etc/group" ).each do | line |
  fields = line.split(':')
  @gids[fields[2].to_i] = fields[0]
end  # open( "/etc/group" )
# Likewise, slurp up /etc/passwd file into hash { uid => user, ... }
@uids = Hash.new{ "" }
open( "/etc/passwd" ).each do | line |
  fields = line.split(':')
  @uids[fields[2].to_i] = fields[0]
end  # open( "/etc/passwd" )
#~ pp @@gids
#~ pp @@uids

  # Compare this hack:
  # Getting file ownership info the system-expensive way:
  #   fowner = %x{stat --printf="%U:%G (%u,%g)" "#{f}"}

  # Translate a uid:gid integer pair into
  # human-readable strings "username:groupname"
  def self.translate_uid_gid( uid, gid )
    return "#{@uids[uid]}:#{@gids[gid]}"
  end  # translate_uid_gid

  # Translate a file's ownership (uid:gid integers) pair into
  # human-readable strings "username:groupname (uid:gid)"
  def self.owner_human_readable( fstat )
    uid = fstat.uid
    gid = fstat.gid
    ug  = translate_uid_gid( uid, gid )
    return ug + " (#{uid}:#{gid})"
  end  # owner_human_readable

  # Returns true if [uid,gid] fstat for file-resource (its ownership)
  # is equal to the [puid,pgid] for "this process"... false otherwise:
  def self.ownedby_user( fstat,
                         puid = Process::Sys.getuid,
                         pgid = Process::Sys.getgid )
    return ( puid == fstat.uid ) && ( pgid == fstat.gid )
  end  # ownedby_user

  # Like ls -h or --human-readable, produces file sizes in
  # human readable format (e.g., 1.1K, 2.2M, 3.3G, etc.)
  def self.size_human_readable( fsize )
    return fsize.to_s if fsize < ONEKILO
    case fsize
    when ONEKILO...ONEMEGA
      return sprintf( "%5.1fK", fsize.to_f / ONEKILO )
    when ONEMEGA...ONEGIGA
      return sprintf( "%5.1fM", fsize.to_f / ONEMEGA )
    when ONEGIGA...ONETERA
      return sprintf( "%5.1fG", fsize.to_f / ONEGIGA )
    when ONETERA...ONEPETA
      return sprintf( "%5.1fT", fsize.to_f / ONETERA )
    when ONETERA...ONEEXA
      return sprintf( "%5.1fP", fsize.to_f / ONEPETA )
    else
      return ">1Exa"
    end  # case fsize
  end  # size_human_readable

  # Hack: rather than convert the octal-integer to the appropriate
  #       "drwxrwxrwx" string, fork a call to shell's stat utility:
  #
  #       prot = %x{stat --printf="%A" "#{f}"}
  #
  # This is system-expensive (forks a sub-process for every call).
  # Better replaced by the following method...

  # Translate a file's mode (protection mask) integer value
  # into a readable string (e.g., 0644 = "-rw-r--r--" and
  # 755 = "-rwxr-xr-x")
  def self.mode_human_readable( fstat )
    m = fstat.mode
    perm = ""
    3.times do
      3.times do |i|
        perm = ( m % 2 == 1 ? "xwr"[i] : "-" ) + perm
        m >>= 1  # right-shift m one bit
      end  # 3.times
    end  # 3.times
    case fstat.ftype
    when "directory"
      perm = "d" + perm
    when "link"
      perm = "l" + perm
    else
      perm = "-" + perm
    end  # case
    return perm
  end  # mode_human_readable

  def self.mode_human_readable_VMS( fstat )
    perm = mode_human_readable( fstat )
    return perm[0] + ' O:' + perm[1..3] + ' G:' + perm[4..6] + ' W:' + perm[7..9]
  end  # mode_human_readable_VMS

   # While File.readlink behaves like the analogous shell command,
  # File.readlink! behaves like 'readlink --canonicalize (-f)',
  # i.e., follow every symlink recursively; all but the last file
  # component must exist:
  def self.readlink!(path)
    path = File.expand_path(path)
    dirname = File.dirname(path)
    readlink = File.readlink(path)
    if not readlink =~ /^\// # it's a relative path
      readlink = dirname + '/'+ readlink # make it absolute
    end
    readlink = File.expand_path(readlink) # eliminate this/../../that
    if File.symlink?(readlink)
      return File.readlink!(readlink) # recursively follow symlinks
    else
      return readlink
    end
  end  # File.readlink!

end  # class File
