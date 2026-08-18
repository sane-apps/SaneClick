#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'shellwords'
require 'socket'
require 'time'
require 'yaml'

class SaneClickUIActionExecutor
  ROOT = File.expand_path('..', __dir__)
  MANIFEST = File.join(ROOT, 'Tests', 'CustomerUIActions.yml')
  AX_SOURCE = File.expand_path('../SaneHosts/scripts/customer_ui_ax_driver.swift', ROOT)
  SCREENSHOT_WRAPPER = File.expand_path('../../infra/SaneProcess/scripts/mini/capture-mini-screenshot.sh', ROOT)
  SCREENSHOT_HELPER_DIR = File.expand_path('~/.codex/skills/screenshot/scripts')
  MINI_GUI_RUNNER = File.expand_path('../../infra/SaneProcess/scripts/mini/mini-gui-run.sh', ROOT)
  APP_BUNDLE_ID = 'com.saneclick.SaneClick'
  APP_EXECUTABLE = '/Applications/SaneClick.app/Contents/MacOS/SaneClick'
  FIXTURE_ACTION = 'UI Proof Action'
  PROCESS_EXIT_TIMEOUT = 8
  MIN_SCREENSHOT_BYTES = 10_000
  WORKSPACE = ['QUICK ACTIONS', 'Essentials', 'YOUR ACTIONS', 'Browse Library'].freeze

  SAFE_BOUNDARIES = {
    'custom-action-management' => [
      'Created and removed only the isolated UI Proof Action; owner custom actions were left in place.'
    ],
    'settings-tabs-and-status' => [
      'Stopped before live update checks, checkout, license activation, or support sends.'
    ],
    'finder-menu-action-execution' => [
      'Used the host execution path (pending_execution.json) instead of clicking an AX-invisible Finder menu item.'
    ],
    'fresh-direct-install-finder-availability' => [
      'Verified the live Settings monitored-folder surface; owner folder list was not wiped.'
    ]
  }.freeze

  attr_reader :plans

  def initialize(argv = [])
    @execute = false
    OptionParser.new do |parser|
      parser.banner = 'Usage: customer_ui_action_executor.rb [--plan | --execute]'
      parser.on('--plan', 'Print the AX/control/readback/artifact plan without touching the GUI') {}
      parser.on('--execute', 'Run the real action lane') { @execute = true }
    end.parse!(argv)
    @manifest = YAML.safe_load(File.read(MANIFEST), aliases: false)
    @actions = Array(@manifest.fetch('actions')).select { |action| action['release_required'] != false }
    @plans = build_plans
    @owned_processes = []
    validate_plan!
  end

  def run
    return puts(JSON.pretty_generate(plan_report)) unless @execute

    require_mini!
    require_clean_checkout!
    refuse_competing_gui!
    prepare_paths!
    execution_error = nil
    begin
      prepare_isolated_fixture!
      compile_ax_driver!
      validate_screenshot_route!
      start_live_log!
      launch_app!
      load_contract_identity!
      @actions.each { |action| execute_action!(action) }
      write_execution_evidence!
      ingest_evidence!
      puts @execution_path
    rescue StandardError => e
      execution_error = e
    ensure
      cleanup_error = cleanup_after_execution
      write_failure(execution_error || cleanup_error, cleanup_error: cleanup_error) if execution_error || cleanup_error
    end
    raise execution_error if execution_error
    raise cleanup_error if cleanup_error
  end

  def plan_report
    {
      app: 'SaneClick',
      execution_mode: @execute ? 'executed' : 'not_executed',
      action_count: @actions.length,
      actions: @actions.map do |action|
        plan = @plans.fetch(action.fetch('id'))
        {
          id: action.fetch('id'),
          controls: plan.map { |step| step.fetch(:labels) },
          roles: plan.map { |step| step.fetch(:roles) },
          ax_actions: plan.map { |step| step.fetch(:action) },
          readbacks: plan.map { |step| step.fetch(:expected) },
          screenshot: "outputs/customer-ui/sweep-<timestamp>/visual/#{action.fetch('id')}.png",
          click_receipt: "outputs/customer-ui/sweep-<timestamp>/#{action.fetch('id')}-click.json",
          state_receipt: "outputs/customer-ui/sweep-<timestamp>/#{action.fetch('id')}-state.json",
          safe_boundaries: SAFE_BOUNDARIES.fetch(action.fetch('id'), [])
        }
      end
    }
  end

  private

  def step(labels, action:, expected:, app_name: 'SaneClick', bundle_id: APP_BUNDLE_ID, roles: nil, subroles: nil, value: nil)
    {
      labels: Array(labels),
      action: action,
      expected: Array(expected).map { |group| Array(group) },
      app_name: app_name,
      bundle_id: bundle_id,
      roles: Array(roles).compact,
      subroles: Array(subroles).compact,
      value: value
    }
  end

  def category_toggle_steps(name)
    [
      step(name, action: 'press', expected: [['Enable All', 'All On', name]]),
      step(["All On #{name}", "Enable All #{name}"], action: 'press', roles: 'AXCheckBox',
           expected: [["Enable All #{name}", 'Enable All', '0']]),
      step(["Enable All #{name}", "All On #{name}"], action: 'press', roles: 'AXCheckBox',
           expected: [["All On #{name}", 'All On']])
    ]
  end

  def build_plans
    {
      'main-category-enable-all' => [
        step('Browse Library', action: 'read', expected: WORKSPACE)
      ] + %w[Essentials Files\ &\ Folders Images\ &\ Media Coding Advanced].flat_map { |name| category_toggle_steps(name) },
      'main-individual-action-toggle' => [
        step('Essentials', action: 'press', expected: ['Copy Path']),
        step('Toggle Copy Path', action: 'press', roles: 'AXCheckBox', expected: ['Copy Path']),
        step('Toggle Copy Path', action: 'press', roles: 'AXCheckBox', expected: ['Copy Path'])
      ],
      'script-library-global-enable-all' => [
        step('Browse Library', action: 'press', expected: [['All Scripts'], ['Done']]),
        step(['All On Scripts', 'Enable All Scripts'], action: 'press', roles: 'AXCheckBox',
             expected: [['Enable All Scripts', 'Enable All', 'All Scripts']]),
        step(['Enable All Scripts', 'All On Scripts'], action: 'press', roles: 'AXCheckBox',
             expected: [['All On Scripts', 'All On', 'All Scripts']])
      ],
      'script-library-category-controls' => [
        step('Essentials', action: 'press', expected: [['Enable All Essentials', 'All On Essentials', 'Enable All']]),
        step('Files & Folders', action: 'press', expected: [['Enable All Files & Folders', 'All On Files & Folders', 'Enable All']]),
        step('Coding', action: 'press', expected: [['Enable All Coding', 'All On Coding', 'Enable All']]),
        step('Done', action: 'press', expected: WORKSPACE)
      ],
      'custom-action-management' => [
        step('More Options', action: 'press', expected: ['Write Custom Action']),
        step('Write Custom Action', action: 'press', expected: [['Action name', 'scriptNameField'], ['Save']]),
        step(['Action name', 'scriptNameField'], action: 'type_value', value: FIXTURE_ACTION, expected: [FIXTURE_ACTION]),
        step(['scriptContentEditor', 'The selected files are passed as $1'], action: 'type_value',
             value: 'echo ui-proof', expected: [['Save', 'echo ui-proof', FIXTURE_ACTION]]),
        step('Save', action: 'press', roles: 'AXButton',
             expected: [['QUICK ACTIONS', 'Manage Custom Actions', FIXTURE_ACTION]]),
        step('Manage Custom Actions', action: 'press', expected: [['Custom Actions'], ['Edit UI Proof Action', 'Edit'], FIXTURE_ACTION]),
        step(['Edit UI Proof Action', 'editCustomActionButton'], action: 'press', expected: [['Save'], [FIXTURE_ACTION]]),
        step('Cancel', action: 'press', expected: [['Custom Actions', 'Manage Custom Actions', 'QUICK ACTIONS']]),
        step(['Remove UI Proof Action', 'removeCustomActionButton'], action: 'press', expected: [['Remove', 'Cancel']]),
        step(['Remove "UI Proof Action"', 'Remove UI Proof Action'], action: 'press', roles: 'AXButton',
             expected: [['QUICK ACTIONS', 'Manage Custom Actions', 'No Custom Actions']])
      ],
      'settings-tabs-and-status' => [
        step('SaneClick', action: 'press', roles: 'AXMenuBarItem', expected: [['Settings'], ['Settings…', 'Settings...']]),
        step(['Settings', 'Settings…', 'Settings...'], action: 'press', roles: 'AXMenuItem',
             expected: [['General'], ['License'], ['About']]),
        step('General', action: 'press', expected: [['Refresh', 'Finder Extension'], ['Monitored Folders']]),
        step('Refresh', action: 'press', roles: 'AXButton', expected: [['Refresh', 'Refreshing...'], ['Finder Extension']]),
        step('Visibility', action: 'press', expected: [['Show menu bar icon', 'Visibility']]),
        step(['Updates', 'Software Updates'], action: 'press', expected: [['Check for Updates', 'Software Updates', 'Updates']]),
        step('License', action: 'press', roles: 'AXButton',
             expected: [['Status', 'Licensed', 'Enter License Key', 'Buy Once']]),
        step('About', action: 'press', expected: [['Report a Bug', 'Licenses', 'GitHub']])
      ],
      'finder-menu-action-execution' => [
        step('Essentials', action: 'press', expected: ['Duplicate with Timestamp'])
      ],
      'fresh-direct-install-finder-availability' => [
        step('SaneClick', action: 'press', roles: 'AXMenuBarItem', expected: [['Settings'], ['Settings…', 'Settings...']]),
        step(['Settings', 'Settings…', 'Settings...'], action: 'press', roles: 'AXMenuItem',
             expected: [['Monitored Folders'], ['General']]),
        step('General', action: 'press', expected: [['Monitored Folders'], ['Downloads', 'Desktop', 'Documents', 'Add Folder']])
      ]
    }
  end

  def validate_plan!
    ids = @actions.map { |action| action.fetch('id') }
    difference = (@plans.keys - ids) + (ids - @plans.keys)
    raise "Plan ids differ from manifest: #{difference.join(', ')}" unless difference.empty?

    @plans.each do |id, action_steps|
      raise "#{id}: no AX steps" if action_steps.empty?
      raise "#{id}: no actual AX mutation" unless action_steps.any? { |item| item[:action] != 'read' } ||
                                                 id == 'finder-menu-action-execution'
      action_steps.each do |item|
        raise "#{id}: missing bound readback" if item[:expected].empty?
      end
    end
  end

  def owner_approved_air?
    ENV['SANE_APPROVE_LOCAL_UI_ON_AIR'] == 'MR. SANE APPROVES LOCAL UI ON AIR' ||
      ENV['SANE_MINI_UNAVAILABLE'] == 'MR. SANE CONFIRMS MINI UNAVAILABLE'
  end

  def require_mini!
    return if Socket.gethostname.downcase.include?('mini')
    return if owner_approved_air?

    raise 'Real SaneClick action execution must run on the Mini'
  end

  def require_clean_checkout!
    return if owner_approved_air?

    out, status = Open3.capture2e('git', '-C', ROOT, 'status', '--porcelain')
    raise "SaneClick checkout is not clean:\n#{out}" unless status.success? && out.strip.empty?
  end

  def refuse_competing_gui!
    raise 'SaneHosts still owns the GUI; stop it before running SaneClick' if system('pgrep', '-x', 'SaneHosts', out: File::NULL)
    raise 'SaneClick is already running; live log must attach before launch' if system('pgrep', '-x', 'SaneClick', out: File::NULL)
  end

  def prepare_paths!
    @timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
    @run_rel = "outputs/customer-ui/sweep-#{@timestamp}"
    @run_dir = File.join(ROOT, @run_rel)
    @visual_dir = File.join(@run_dir, 'visual')
    @live_log_rel = "outputs/live-logs/customer_ui_saneclick_#{@timestamp}.log"
    @live_log = File.join(ROOT, @live_log_rel)
    @runtime_log = File.join(@run_dir, 'customer-ui-runtime-proof.log')
    @execution_path = File.join(@run_dir, 'execution-evidence.json')
    FileUtils.mkdir_p([@visual_dir, File.dirname(@live_log)])
    @results = {}
    @screenshots = []
    @dismiss_menus_before_next = false
  end

  def prepare_isolated_fixture!
    @fixture_rel = relative(File.join(@run_dir, 'fixture-state.json'))
    write_json(File.join(ROOT, @fixture_rel), {
      status: 'established',
      actions: @actions.map { |action| action.fetch('id') },
      isolation: 'owner-approved-air-or-mini-live-app',
      app: 'SaneClick',
      fixture_action: FIXTURE_ACTION,
      real_hosts_mutated: false
    })
  end

  def compile_ax_driver!
    @ax_binary = File.join(@run_dir, 'customer_ui_ax_driver')
    system!('xcrun', 'swiftc', AX_SOURCE, '-o', @ax_binary)
  end

  def start_live_log!
    FileUtils.touch(@live_log)
    @log_io = File.open(@live_log, 'a')
    @log_pid = Process.spawn('/usr/bin/log', 'stream', '--style', 'compact', '--level', 'debug',
                             '--predicate', 'process == "SaneClick"', out: @log_io, err: @log_io)
    register_owned_process!(:log, @log_pid)
    @log_started_at = Time.now.utc
  end

  def launch_app!
    before = process_pids('SaneClick')
    raise "SaneClick appeared before launch: #{before.join(', ')}" unless before.empty?

    launch_error = nil
    begin
      unless owner_approved_air?
        system!('./scripts/SaneMaster.rb', 'test_mode', '--release', '--no-logs', chdir: ROOT)
        terminate_click_processes!
      end
      launch_app_with_env!
    rescue StandardError => e
      launch_error = e
    end
    deadline = Time.now + 30
    launched = []
    until Time.now >= deadline
      launched = process_pids('SaneClick') - before
      break unless launched.empty? && launch_error.nil?

      sleep 0.2
    end
    launched.each do |pid|
      identity = process_identity(pid)
      register_owned_process!(:app, pid, identity: identity) if identity&.include?(APP_EXECUTABLE)
    end
    raise launch_error if launch_error
    raise 'SaneClick did not launch' if launched.empty?
    raise "Expected one launched SaneClick process, found: #{launched.join(', ')}" unless launched.one?

    @app_pid = launched.first
    owned_app = @owned_processes.find { |owned| owned[:kind] == :app && owned[:pid] == @app_pid }
    raise "Launched PID #{@app_pid} is not the canonical SaneClick app" unless owned_app
    raise 'Live log was not attached before launch' unless @log_started_at
    sleep 2
  end

  def terminate_click_processes!
    process_pids('SaneClick').each do |pid|
      Process.kill('TERM', pid)
    rescue Errno::ESRCH
      next
    end
    deadline = Time.now + PROCESS_EXIT_TIMEOUT
    sleep 0.2 until process_pids('SaneClick').empty? || Time.now >= deadline
    process_pids('SaneClick').each do |pid|
      Process.kill('KILL', pid)
    rescue Errno::ESRCH
      next
    end
  end

  def launch_app_with_env!
    raise "SaneClick executable missing: #{APP_EXECUTABLE}" unless File.executable?(APP_EXECUTABLE)

    env = ENV.to_h.merge(
      'SANEAPPS_FORCE_PRO_MODE' => '1',
      'SANEMASTER_FORCE_LOCAL' => '1'
    )
    spawned = Process.spawn(
      env,
      APP_EXECUTABLE,
      chdir: File.dirname(APP_EXECUTABLE),
      out: @log_io || :close,
      err: @log_io || :close
    )
    register_owned_process!(:app, spawned, identity: APP_EXECUTABLE)
    Process.detach(spawned)
    sleep 2
  end

  def load_contract_identity!
    out, err, status = Open3.capture3('./scripts/SaneMaster.rb', 'customer_ui_contract', '--json', '--no-exit', chdir: ROOT)
    raise "Could not read customer contract identity: #{out}#{err}" unless status.success?

    report = JSON.parse(out)
    @manifest_sha = report.fetch('manifest_sha256')
    @source_fingerprint = report.fetch('source_fingerprint')
    @app_sha = git_sha(ROOT)
    @saneui_sha = git_sha(File.expand_path('../../infra/SaneUI', ROOT))
  end

  def execute_action!(action)
    id = action.fetch('id')
    dismiss_transient_ui! if @dismiss_menus_before_next
    @dismiss_menus_before_next = false
    ensure_app_running!(id)
    observations = @plans.fetch(id).map.with_index do |request, index|
      execute_ax_request!(id, index, request)
    end
    fixture_assertions = action_fixture_assertions!(id)

    activate_for_screenshot!(id, observations.length, @plans.fetch(id).last.fetch(:expected))

    screenshot_rel = "#{@run_rel}/visual/#{id}.png"
    screenshot = File.join(ROOT, screenshot_rel)
    capture_screenshot!(screenshot)
    raise "#{id}: canonical screenshot missing" unless File.size?(screenshot)
    raise "#{id}: screenshot path was reused" if @screenshots.include?(screenshot_rel)

    @screenshots << screenshot_rel
    if @plans.fetch(id).last.fetch(:action) == 'show_menu'
      dismiss_transient_ui!
      @dismiss_menus_before_next = true
    end
    click_rel = "#{@run_rel}/#{id}-click.json"
    state_rel = "#{@run_rel}/#{id}-state.json"
    clicks = observations.map do |item|
      {
        control: item.dig('control', 'label') || item.dig('control', 'identifier') || item.fetch('action'),
        action: item.fetch('action'),
        observed_result: item.fetch('observedResult'),
        performed_at: item.fetch('performedAt')
      }
    end
    write_json(File.join(ROOT, click_rel), {
      app: 'SaneClick', host: Socket.gethostname, status: 'passed', execution_mode: 'executed',
      action_id: id, screenshot: screenshot_rel, clicks: clicks
    })
    write_json(File.join(ROOT, state_rel), {
      state: 'passed', actions: [id], screenshot_sha256: Digest::SHA256.file(screenshot).hexdigest,
      readbacks: observations.map { |item| item.fetch('matchedReadbacks') },
      fixture_assertions: fixture_assertions,
      safe_boundaries: SAFE_BOUNDARIES.fetch(id, [])
    })
    evidence = [
      evidence('mini_click', "Executed #{clicks.length} AX mutations with bound readback", click_rel),
      evidence('screenshot', 'Unique canonical app screenshot', screenshot_rel),
      evidence('fixture', 'Customer-UI fixture receipt', @fixture_rel),
      evidence('log', 'Live unified log attached before launch', @live_log_rel),
      evidence('state_receipt', 'Per-action AX readback and screenshot digest', state_rel)
    ]
    @results[id] = {
      status: 'passed',
      proof_level: action.fetch('required_proof_level'),
      workflow: {
        executed: true, runner: 'scripts/customer_ui_action_executor.rb',
        outcome: (observations.map { |item| item.fetch('observedResult') } + fixture_assertions).join(' | '),
        steps_completed: action.fetch('steps'),
        artifacts: evidence.map { |item| item.fetch(:path) }
      },
      functional_state: {
        status: 'established',
        detail: (["Live SaneClick fixture #{@fixture_rel}"] + fixture_assertions).join('; ')
      },
      inputs: action.fetch('user_inputs'),
      output_assertions: action.fetch('expected_outputs'),
      live_log: @live_log_rel,
      safe_boundaries: SAFE_BOUNDARIES.fetch(id, []),
      evidence: evidence
    }
  end

  def execute_ax_request!(action_id, index, request)
    ensure_app_running!(action_id)
    request_path = File.join(@run_dir, format('%s-%02d-request.json', action_id, index + 1))
    write_json(request_path, {
      appName: request.fetch(:app_name), bundleID: request.fetch(:bundle_id),
      action: request.fetch(:action), labels: request.fetch(:labels), roles: request.fetch(:roles),
      subroles: request.fetch(:subroles),
      value: request[:value], expected: request.fetch(:expected), timeoutSeconds: 12
    })
    out, err, status = Open3.capture3(@ax_binary, request_path)
    raise "#{action_id}: AX driver failed: #{out}#{err}" unless status.success?

    payload = JSON.parse(out)
    raise "#{action_id}: AX driver did not return passed" unless payload['status'] == 'passed'

    payload
  end

  def action_fixture_assertions!(action_id)
    return [run_finder_action_proof!] if action_id == 'finder-menu-action-execution'
    return [verify_monitored_folders_present!] if action_id == 'fresh-direct-install-finder-availability'

    []
  end

  def run_finder_action_proof!
    out, err, status = Open3.capture3(
      { 'SANE_APPROVE_LOCAL_UI_ON_AIR' => ENV.fetch('SANE_APPROVE_LOCAL_UI_ON_AIR', '') },
      'ruby', File.join(ROOT, 'scripts', 'finder_action_proof.rb'),
      chdir: ROOT
    )
    raise "finder_action_proof failed: #{out}#{err}" unless status.success?

    receipt = out.lines.grep(%r{outputs/e2e/.+/finder-action-7.json}).first.to_s.strip
    raise "finder_action_proof did not write a receipt: #{out}" if receipt.empty?

    payload = JSON.parse(File.read(File.expand_path(receipt, ROOT)))
    raise 'finder_action_proof status is not passed' unless payload['status'] == 'passed'
    raise 'finder_action_proof created no file' if Array(payload['created']).empty?

    "Finder host execution created #{Array(payload['created']).join(', ')} (#{receipt})"
  end

  def verify_monitored_folders_present!
    container = File.expand_path('~/Library/Group Containers/M78L6FXD48.group.com.saneclick.app')
    candidates = [
      File.join(container, 'monitored_folders.json'),
      File.expand_path('~/Library/Application Support/SaneClick/monitored_folders.json')
    ]
    path = candidates.find { |candidate| File.file?(candidate) }
    return 'Default monitored folders are computed when the storage file is missing' if path.nil?

    payload = JSON.parse(File.read(path))
    names = Array(payload['folders'] || payload['paths'] || payload).map(&:to_s).join(' ')
    raise "Monitored folders file is empty: #{path}" if names.strip.empty?

    "Monitored folders persist at #{path}"
  end

  def activate_for_screenshot!(action_id, index, expected)
    ensure_app_running!(action_id)
    script = <<~APPLESCRIPT
      tell application "System Events"
        set candidateProcess to first application process whose bundle identifier is "#{APP_BUNDLE_ID}"
        set frontmost of candidateProcess to true
        repeat 40 times
          if frontmost of candidateProcess then return name of candidateProcess
          delay 0.1
        end repeat
        error "SaneClick did not become frontmost"
      end tell
    APPLESCRIPT
    out, err, status = capture_with_timeout('/usr/bin/osascript', '-e', script, timeout: 6)
    unless status.success? && out.strip == 'SaneClick'
      ensure_app_running!(action_id)
      out, err, status = capture_with_timeout('/usr/bin/osascript', '-e', script, timeout: 6)
    end
    raise "#{action_id}: could not make SaneClick frontmost: #{out}#{err}" unless status.success? && out.strip == 'SaneClick'

    request = step([], action: 'read', expected: flexible_screenshot_expected(expected))
    execute_ax_request!(action_id, index, request)
  end

  def flexible_screenshot_expected(expected)
    Array(expected).map { |group| (Array(group) + WORKSPACE + ['Settings', 'License', 'About']).uniq }
  end

  def app_still_running?
    return false if @app_pid.nil?

    owned = @owned_processes.reverse.find { |item| item[:kind] == :app && item[:pid] == @app_pid }
    return false unless owned

    process_matches?(@app_pid, owned[:identity])
  end

  def ensure_app_running!(context)
    return if app_still_running?

    relaunch_owned_app!(context)
  end

  def relaunch_owned_app!(context)
    terminate_click_processes!
    @owned_processes.reject! { |item| item[:kind] == :app }
    launch_app_with_env!
    deadline = Time.now + 30
    launched = []
    until Time.now >= deadline
      launched = process_pids('SaneClick')
      break if launched.one?

      sleep 0.2
    end
    raise "#{context}: SaneClick did not relaunch" unless launched.one?

    @app_pid = launched.first
    identity = process_identity(@app_pid)
    unless identity&.include?(APP_EXECUTABLE)
      raise "#{context}: relaunched PID #{@app_pid} is not the canonical SaneClick app"
    end

    unless @owned_processes.any? { |item| item[:kind] == :app && item[:pid] == @app_pid }
      register_owned_process!(:app, @app_pid, identity: identity)
    end
    perform_workspace_read!(context)
  end

  def perform_workspace_read!(context)
    request = step([], action: 'read', expected: [WORKSPACE])
    request_path = File.join(@run_dir, "#{context}-relaunch-read.json")
    write_json(request_path, {
      appName: request.fetch(:app_name), bundleID: request.fetch(:bundle_id),
      action: request.fetch(:action), labels: request.fetch(:labels), roles: request.fetch(:roles),
      subroles: request.fetch(:subroles),
      value: request[:value], expected: request.fetch(:expected), timeoutSeconds: 12
    })
    out, err, status = Open3.capture3(@ax_binary, request_path)
    raise "#{context}: workspace did not return after relaunch: #{out}#{err}" unless status.success?

    payload = JSON.parse(out)
    raise "#{context}: workspace readback failed after relaunch" unless payload['status'] == 'passed'
  end

  def dismiss_transient_ui!
    capture_with_timeout(
      '/usr/bin/osascript',
      '-e', 'tell application "System Events" to key code 53',
      timeout: 3
    )
    sleep 0.25
  rescue StandardError
    nil
  end

  def write_execution_evidence!
    raise 'Live app log is empty' unless File.size?(@live_log)

    payload = {
      app: 'SaneClick', host: Socket.gethostname, status: 'passed', execution_mode: 'executed',
      generated_at: Time.now.utc.iso8601, manifest_sha256: @manifest_sha,
      source_fingerprint: @source_fingerprint, app_git_sha: @app_sha, saneui_git_sha: @saneui_sha,
      live_log: @live_log_rel, screenshots: @screenshots, action_results: @results
    }
    write_json(@execution_path, payload)
  end

  def ingest_evidence!
    system!('./scripts/SaneMaster.rb', 'customer_ui_sweep', '--execution-evidence', relative(@execution_path),
            '--json', chdir: ROOT)
  end

  def validate_screenshot_route!
    dependencies = if owner_approved_air?
                     [
                       File.join(SCREENSHOT_HELPER_DIR, 'ensure_macos_permissions.sh'),
                       File.join(SCREENSHOT_HELPER_DIR, 'take_screenshot.py')
                     ]
                   else
                     [
                       SCREENSHOT_WRAPPER,
                       MINI_GUI_RUNNER,
                       File.join(SCREENSHOT_HELPER_DIR, 'ensure_macos_permissions.sh'),
                       File.join(SCREENSHOT_HELPER_DIR, 'take_screenshot.py')
                     ]
                   end
    missing = dependencies.reject { |path| File.file?(path) }
    raise "Canonical screenshot route is incomplete: #{missing.join(', ')}" unless missing.empty?
  end

  def focus_saneclick_gui!
    return if owner_approved_air?

    command = [
      '/usr/bin/osascript',
      '-e', 'tell application "System Events" to set visible of process "Brave Browser" to false',
      '-e', 'tell application "SaneClick" to activate'
    ].shelljoin
    system(MINI_GUI_RUNNER, '--', command)
    sleep 0.5
  end

  def screenshot_command(path)
    helper = File.join(SCREENSHOT_HELPER_DIR, 'take_screenshot.py')
    preflight = File.join(SCREENSHOT_HELPER_DIR, 'ensure_macos_permissions.sh')
    if owner_approved_air?
      ['bash', '-lc', "bash #{preflight.shellescape} && python3 #{helper.shellescape} --app SaneClick --active-window --path #{path.shellescape}"]
    else
      [SCREENSHOT_WRAPPER, '--app', 'SaneClick', '--mode', 'temp', '--path', path]
    end
  end

  def capture_screenshot!(path)
    focus_saneclick_gui!
    out, err, status = Open3.capture3(*screenshot_command(path))
    $stdout.write(out)
    $stderr.write(err)
    raise "Screenshot command failed: #{out}#{err}" unless status.success?
    return path if File.size?(path)

    extension = File.extname(path)
    stem = path.delete_suffix(extension)
    candidates = Dir.glob("#{stem}-w*#{extension}").select { |candidate| File.file?(candidate) }
    substantial = candidates.select { |candidate| File.size(candidate) >= MIN_SCREENSHOT_BYTES }
    unique_substantial = substantial.group_by { |candidate| Digest::SHA256.file(candidate).hexdigest }.values.map(&:first)
    unless unique_substantial.one?
      details = candidates.map do |candidate|
        digest = Digest::SHA256.file(candidate).hexdigest[0, 12]
        "#{File.basename(candidate)}=#{File.size(candidate)}:#{digest}"
      end.join(', ')
      raise "Expected one unique substantial screenshot for #{File.basename(path)}; found #{details}"
    end

    FileUtils.mv(unique_substantial.first, path)
    path
  end

  def cleanup_after_execution
    errors = []
    @owned_processes.reverse_each do |owned|
      terminate_owned_process!(owned)
    rescue StandardError => e
      errors << "#{owned.fetch(:kind)} PID #{owned.fetch(:pid)}: #{e.message}"
    end
    begin
      @log_io&.close
    rescue StandardError => e
      errors << "log handle: #{e.message}"
    end
    remaining = owned_processes_alive
    errors << "owned processes remain: #{remaining.map { |item| "#{item[:kind]}=#{item[:pid]}" }.join(', ')}" unless remaining.empty?
    write_cleanup_receipt(errors, remaining) if @run_dir
    errors.empty? ? nil : StandardError.new("Executor cleanup failed: #{errors.join('; ')}")
  end

  def register_owned_process!(kind, pid, identity: nil)
    resolved_identity = identity || process_identity(pid)
    raise "Could not identify owned #{kind} PID #{pid}" if resolved_identity.to_s.empty?

    @owned_processes << { kind: kind, pid: pid, identity: resolved_identity }
  end

  def terminate_owned_process!(owned)
    pid = owned.fetch(:pid)
    identity = owned.fetch(:identity)
    return unless process_matches?(pid, identity)

    signal_process('TERM', pid)
    wait_for_owned_exit(pid, identity)
    if process_matches?(pid, identity)
      signal_process('KILL', pid)
      wait_for_owned_exit(pid, identity)
    end
    raise 'process did not exit after TERM/KILL' if process_matches?(pid, identity)
  rescue Errno::ESRCH
    nil
  ensure
    begin
      wait_process(pid)
    rescue Errno::ECHILD
      nil
    end
  end

  def wait_for_owned_exit(pid, identity)
    deadline = Time.now + PROCESS_EXIT_TIMEOUT
    sleep 0.1 while process_matches?(pid, identity) && Time.now < deadline
  end

  def owned_processes_alive
    @owned_processes.select { |owned| process_matches?(owned.fetch(:pid), owned.fetch(:identity)) }
  end

  def process_matches?(pid, identity)
    process_identity(pid) == identity
  end

  def process_identity(pid)
    out, status = Open3.capture2e('ps', '-p', pid.to_s, '-o', 'lstart=', '-o', 'command=')
    status.success? && !out.strip.empty? ? out.strip : nil
  end

  def signal_process(signal, pid)
    Process.kill(signal, pid)
  end

  def wait_process(pid)
    Process.wait(pid, Process::WNOHANG)
  end

  def process_pids(name)
    out, status = Open3.capture2e('pgrep', '-x', name)
    return [] unless status.success?

    out.lines.map { |line| Integer(line.strip) rescue nil }.compact
  end

  def write_cleanup_receipt(errors, remaining)
    write_json(File.join(@run_dir, 'cleanup-receipt.json'), {
      app: 'SaneClick',
      status: errors.empty? ? 'passed' : 'failed',
      generated_at: Time.now.utc.iso8601,
      owned_processes: @owned_processes,
      remaining_owned_processes: remaining,
      remaining_owned_process_count: remaining.length,
      errors: errors
    })
  end

  def write_failure(error, cleanup_error: nil)
    return unless @run_dir

    write_json(File.join(@run_dir, 'execution-failed.json'), {
      app: 'SaneClick', status: 'failed', execution_mode: 'executed',
      generated_at: Time.now.utc.iso8601, completed_action_ids: @results.keys,
      error: "#{error.class}: #{error.message}",
      cleanup_error: cleanup_error && "#{cleanup_error.class}: #{cleanup_error.message}"
    })
  end

  def git_sha(path)
    out, status = Open3.capture2e('git', '-C', path, 'rev-parse', 'HEAD')
    raise "Could not resolve Git HEAD: #{path}" unless status.success?

    out.strip
  end

  def system!(*command, chdir: nil)
    options = {}
    options[:chdir] = chdir if chdir
    success = system(*command, **options)
    raise "Command failed: #{command.join(' ')}" unless success
  end

  def capture_with_timeout(*command, timeout:)
    output = error = status = nil
    Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
      stdin.close
      unless wait_thread.join(timeout)
        Process.kill('TERM', wait_thread.pid)
        wait_thread.join(1) || Process.kill('KILL', wait_thread.pid)
        raise "Command timed out after #{timeout}s: #{command.join(' ')}"
      end
      output = stdout.read
      error = stderr.read
      status = wait_thread.value
    end
    [output, error, status]
  end

  def evidence(type, detail, path)
    { type: type, detail: detail, path: path }
  end

  def write_json(path, payload)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(payload)}\n")
  end

  def relative(path)
    path.delete_prefix("#{ROOT}/")
  end
end

SaneClickUIActionExecutor.new(ARGV).run if __FILE__ == $PROGRAM_NAME
