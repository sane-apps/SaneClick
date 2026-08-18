#!/usr/bin/env ruby
# frozen_string_literal: true

# Drive the same host execution path Finder Sync uses after a menu click:
# write pending_execution.json, post com.saneclick.executeScript, assert
# the filesystem side effect. Mini only.

require 'fileutils'
require 'json'
require 'socket'
require 'time'
require 'tmpdir'

def air_fallback_approved?
  ENV['SANE_APPROVE_LOCAL_UI_ON_AIR'] == 'MR. SANE APPROVES LOCAL UI ON AIR' ||
    ENV['SANE_MINI_UNAVAILABLE'] == 'MR. SANE CONFIRMS MINI UNAVAILABLE'
end

raise 'finder_action_proof must run on the Mini (Air needs SANE_APPROVE_LOCAL_UI_ON_AIR or SANE_MINI_UNAVAILABLE)' unless Socket.gethostname.downcase.include?('mini') || air_fallback_approved?

ROOT = File.expand_path('..', __dir__)
PROOF_NAME = 'saneclick-proof.txt'
DOWNLOADS = File.expand_path('~/Downloads')
PROOF = File.join(DOWNLOADS, PROOF_NAME)
SCRIPT_ID = '833E61C5-6186-4FEB-BEF1-7EB6CD35A421'
CONTAINER = File.expand_path('~/Library/Group Containers/M78L6FXD48.group.com.saneclick.app')
PENDING = File.join(CONTAINER, 'pending_execution.json')
OUT_DIR = File.join(ROOT, 'outputs', 'e2e', "1.3.3-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}")

raise "SaneClick app group container missing" unless File.directory?(CONTAINER)
File.write(PROOF, "saneclick-proof\n") unless File.file?(PROOF)

# Encode with the same JSONEncoder Date strategy the extension uses
# (seconds since the 2001 reference date), then post the same
# DistributedNotificationCenter signal Finder Sync posts.
encode_and_post = <<~SWIFT
import Foundation

let container = URL(fileURLWithPath: "#{CONTAINER}")
let pending = container.appendingPathComponent("pending_execution.json")
struct ExecutionRequest: Codable {
    let scriptId: UUID
    let paths: [String]
    let timestamp: Date
    let requestId: UUID
}
let request = ExecutionRequest(
    scriptId: UUID(uuidString: "#{SCRIPT_ID}")!,
    paths: ["#{PROOF}"],
    timestamp: Date(),
    requestId: UUID()
)
let data = try JSONEncoder().encode(request)
try data.write(to: pending, options: .atomic)
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.saneclick.executeScript"),
    object: nil,
    userInfo: nil,
    deliverImmediately: true
)
print("posted")
SWIFT

tmp = File.join(Dir.tmpdir, "saneclick-notify-#{Process.pid}.swift")
File.write(tmp, encode_and_post)
unless system('pgrep', '-x', 'SaneClick', out: File::NULL)
  system('open', '-a', 'SaneClick', '--args', '--saneclick-execution-requested') || raise('could not launch SaneClick')
  deadline = Time.now + 15
  until system('pgrep', '-x', 'SaneClick', out: File::NULL)
    raise 'SaneClick did not launch' if Time.now >= deadline
    sleep 0.2
  end
  sleep 1.5
end

before = Dir.children(DOWNLOADS).select { |name| name.start_with?('saneclick-proof') }.sort
system('xcrun', 'swift', tmp) || raise('could not write pending request or post executeScript')
File.delete(tmp) if File.file?(tmp)

deadline = Time.now + 8
after = before
until Time.now >= deadline
  after = Dir.children(DOWNLOADS).select { |name| name.start_with?('saneclick-proof') }.sort
  break if after.length > before.length
  sleep 0.2
end

created = after - before
FileUtils.mkdir_p(OUT_DIR)
receipt = {
  app: 'SaneClick',
  host: Socket.gethostname,
  generated_at: Time.now.utc.iso8601,
  status: created.empty? ? 'failed' : 'passed',
  execution_mode: 'executed',
  path: 'Finder Sync host execution (pending_execution.json + com.saneclick.executeScript)',
  before: before,
  after: after,
  created: created,
  proof: PROOF,
  script_id: SCRIPT_ID
}
receipt_path = File.join(OUT_DIR, 'finder-action-7.json')
File.write(receipt_path, JSON.pretty_generate(receipt))
puts receipt_path
puts JSON.pretty_generate(receipt)
exit(created.empty? ? 1 : 0)
