#!/usr/bin/ruby
# Copyright (c) 2009, 2012, 2013 joshua stein <jcs@jcs.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require File.dirname(__FILE__) << "/lib/itunes"

if !ARGV[1]
  puts "usage: #{$0} <itunes playlist> <destination directory>"
  exit
end

playlist = ARGV[0]

if Dir[ARGV[1]].any?
  destdir = ARGV[1]

  if !destdir.match(/\/$/)
    destdir += "/"
  end
else
  puts "error: directory \"#{destdir}\" does not exist, exiting"
  exit 1
end

puts "querying itunes for playlist \"#{playlist}\"..."

it = ITunes.new
pl = it.playlist(playlist)

mbytes = pl.total_bytes.to_f / (1024 * 1024)

puts "found #{pl.tracks.length} track#{pl.tracks.length == 1 ? "" : "s"} " <<
  "with size " << sprintf("%0.2fMb", mbytes)

# make sure the destination can hold this playlist
df_m = `df -m #{destdir}`.split("\n").last.split(" ")[1].to_i
if mbytes > df_m
  puts "error: #{destdir} has size of #{df_m}Mb, need #{mbytes.ceil}Mb to sync"
  exit 1
end

td = `mktemp -d /tmp/itunes-rsync.XXXXX`.strip

# link each track into the workspace
print "linking files under #{td}/... "
pl.tracks.each do |t|
  next if !t.enabled?
  tmppath = td + "/" + t.safe_filename_without_gcd

  if !Dir[File.dirname(tmppath)].any?
    system("mkdir", "-p", File.dirname(tmppath))
  end

  File.symlink(t.location, tmppath)
end

puts "done."

# file times don't ever seem to match up, so only check size
puts "rsyncing to #{destdir}... "
system("rsync", "--exclude=.audio_data", "-Lrv", "--size-only", "--progress",
       "--delete", "#{td}/", destdir)

print "cleaning up... "
system("rm", "-rf", td)

puts "done."
