#!/usr/bin/env ruby

require "digest"

version, archive, template, output = ARGV
abort "usage: update-cask.rb <version> <archive> <template> <output>" unless output

content = File.read(template)
content.sub!(/version "[^"]+"/, %(version "#{version}"))
content.sub!(/sha256 (?:"[^"]+"|:no_check)/, %(sha256 "#{Digest::SHA256.file(archive).hexdigest}"))
File.write(output, content)
