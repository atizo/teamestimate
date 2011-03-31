#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#
# teamestimate - Independent team time estimation for Redmine
# https://labs.atizo.com/software/#teamestimate
#
# Copyright (c) 2011 Atizo AG. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

require 'rubygems'
require 'active_resource'
require 'highline/import'
require 'pp'


# Your team members
team = [
  'john',
  'bob',
  'anna',
  'emily',
]

# Location of your Redmine site
$redmine_url = 'https://redmine.example.org/'

# API key (copy from 'My account', 'API access key')
$redmine_api_key = '8809f980b2af1ab0f4eb2be29787aba8d0070759'


class RedmineResource < ActiveResource::Base
  self.site = $redmine_url
  self.user = $redmine_api_key
  self.password = 'X'
end

class Project < RedmineResource
end

class Issue < RedmineResource
end

def ask_issue
  issue = nil
  while issue.nil? do
    begin
      issue_id = ask('Issue ID (return to skip): ')
      if issue_id == '' then
        return nil
      end
      issue_id = Integer(issue_id)
      begin
        issue = Issue.find(issue_id)
      rescue ActiveResource::ResourceNotFound
        puts "Error: Issue ##{issue_id} does not exist"
      rescue
        puts 'Error: Unable to connect to Redmine server'
      end
    rescue
      puts 'Error: Not an integer!'
    end
  end

  return issue
end

if __FILE__ == $0
  begin
    while true do
      estimates = {}
      estimates_string = ''

      team.shuffle!
      team.each do |name|
        est = nil
        while est.nil? do
          begin
            est = Float(ask("#{name}: ") { |q| q.echo = false })
          rescue ArgumentError
            puts 'Error: Not a float!'
            est = nil
          end
        end
        estimates[name] = est
      end
      puts ''

      total = 0.0
      team.each do |name|
        est = estimates[name]
        line = sprintf "%s: %.2f", name, est
        puts line
        estimates_string << line+"\n"
        total += est
      end
      average = total / team.length
      rounded_average = average.ceil

      line = '---------------'
      puts line
      estimates_string << line+"\n"

      line = sprintf "average: %.2f (rounded: %d)", average, rounded_average
      puts line
      puts ''
      estimates_string << line+"\n\n"

      skip = false
      confirmation = nil
      while not skip and confirmation.nil? do
        issue = ask_issue
        if issue.nil?
          skip = true
          break
        end

        estimated_hours = nil
        while estimated_hours.nil? do
          estimated_hours = ask("Estimated hours [#{rounded_average}]: ")
          if estimated_hours == ''
            estimated_hours = rounded_average
            break
          end
          begin
            estimated_hours = Integer(estimated_hours)
          rescue ArgumentError
            puts 'Error: not an integer'
            estimated_hours = nil
          end
        end

        puts ''
        puts "Issue: ##{issue.id} #{issue.subject}"
        puts "Estimated hours: #{estimated_hours}"
        while not ['', 'Y', 'y', 'n'].include?(confirmation) do
          confirmation = ask('Correct? [Y/n]: ')
        end

        if confirmation == 'n'
          confirmation = nil
          puts ''
        else
          issue.estimated_hours = estimated_hours
          issue.notes = estimates_string
          issue.save
          puts "Issue ##{issue.id} saved."
        end
      end

      puts ''
    end

  rescue Interrupt:
    # handle Ctrl-C silently
  end
end
