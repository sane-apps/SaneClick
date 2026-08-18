#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'socket'
require 'time'
require 'yaml'

class CustomerUIActionSweep
  PROJECT_ROOT = File.expand_path('..', __dir__)
  OUTPUT_DIR = File.join(PROJECT_ROOT, 'outputs', 'customer-ui')
  RECEIPT_PATH = File.join(PROJECT_ROOT, '.sane', 'customer_ui_action_receipt.json')
  MIRROR_RECEIPT_PATH = File.join(PROJECT_ROOT, 'outputs', 'customer_ui_action_receipt.json')
  MANIFEST_PATH = File.join(PROJECT_ROOT, 'Tests', 'CustomerUIActions.yml')
  SANEMASTER = File.join(PROJECT_ROOT, 'scripts', 'SaneMaster.rb')
  APP_NAME = 'SaneClick'

  ACTION_GUARDS = {
    'main-category-enable-all' => [
      ['SaneClick/Views/ContentView.swift', 'Enable All'],
      ['SaneClick/Views/ContentView.swift', 'scriptStore.setLibraryScripts'],
      ['SaneClick/Services/ScriptStore.swift', 'func setLibraryScripts'],
      ['Tests/ScriptStoreTests.swift', 'Library activation is live and deduplicates stale installed copies']
    ],
    'main-individual-action-toggle' => [
      ['SaneClick/Views/ContentView.swift', 'Toggle'],
      ['SaneClick/Services/ScriptStore.swift', 'func setLibraryScript'],
      ['Tests/ScriptStoreTests.swift', 'store.setLibraryScript(libraryScript, isEnabled: false)'],
      ['Tests/ScriptStoreTests.swift', 'store.setLibraryScript(libraryScript, isEnabled: true)']
    ],
    'script-library-global-enable-all' => [
      ['SaneClick/Views/ScriptLibraryView.swift', 'All Scripts'],
      ['SaneClick/Views/ScriptLibraryView.swift', 'Enable All'],
      ['SaneClick/Views/ScriptLibraryView.swift', 'scriptStore.setLibraryScripts'],
      ['Tests/ScriptLibraryTests.swift', 'Library has 50+ scripts']
    ],
    'script-library-category-controls' => [
      ['SaneClick/Views/ScriptLibraryView.swift', 'ScriptLibrary.availableCategories'],
      ['SaneClick/Views/ScriptLibraryView.swift', 'availableScripts(for: category)'],
      ['SaneClick/Views/ScriptLibraryView.swift', 'scriptStore.setLibraryScript'],
      ['Tests/ScriptLibraryTests.swift', 'All categories have scripts']
    ],
    'custom-action-management' => [
      ['SaneClick/Views/ScriptEditorView.swift', 'ScriptEditorView'],
      ['SaneClick/Views/CategoryEditorView.swift', 'CategoryEditorView'],
      ['SaneClick/Views/ImportExportView.swift', 'ImportExportView'],
      ['Tests/ScriptLibraryTests.swift', 'customActionsAreSeparatedFromLibraryActions'],
      ['Tests/ScriptStoreTests.swift', 'Library activation preserves custom action with same name']
    ],
    'settings-tabs-and-status' => [
      ['SaneClick/Views/SettingsView.swift', 'SaneSettingsContainer'],
      ['SaneClick/Views/SettingsView.swift', 'SaneClickSettingsCopy.refreshButtonTitle'],
      ['SaneClick/Views/SettingsView.swift', 'LicenseSettingsView'],
      ['SaneClick/Services/MenuBarController.swift', 'About / Report a Bug...'],
      ['Tests/AppStoreReviewGuardrailTests.swift', 'Settings use shared SaneUI shell and standardized direct license copy']
    ],
    'finder-menu-action-execution' => [
      ['SaneClickExtension/FinderSync.swift', 'menu(for menuKind: FIMenuKind)'],
      ['SaneClickExtension/FinderSync.swift', 'selectedItemURLs()'],
      ['SaneClick/Services/ScriptExecutor.swift', 'execute'],
      ['Tests/ScriptExecutorTests.swift', 'Representative right-click actions complete for every category'],
      ['Tests/ScriptTests.swift', 'AppliesTo rejects wrong Finder selection kind']
    ],
    'fresh-direct-install-finder-availability' => [
      ['Shared/MonitoredFolders.swift', 'seedInitialDefaultFoldersIfNeeded()'],
      ['Shared/MonitoredFolders.swift', 'initialDefaultFolders()'],
      ['Shared/MonitoredFolders.swift', 'monitoredFoldersUserConfigured'],
      ['SaneClick/Views/SettingsView.swift', 'SaneClickSettingsCopy.monitoredFoldersSectionTitle'],
      ['Tests/AppStoreReviewGuardrailTests.swift', 'Direct builds expose monitored folder setup instead of silent empty Finder registration']
    ]
  }.freeze

  ARTIFACT_REFERENCES = {
    'main-category-enable-all' => 'outputs/customer-ui/content-all-actions.png',
    'main-individual-action-toggle' => 'docs/screenshots/main-window.png',
    'script-library-global-enable-all' => 'outputs/customer-ui/library-all-actions.png',
    'settings-tabs-and-status' => 'outputs/customer-ui/settings-fresh-direct-monitored-folders.png',
    'finder-menu-action-execution' => 'outputs/customer-ui/finder-menu-image-file.png',
    'fresh-direct-install-finder-availability' => 'outputs/customer-ui/fresh-direct-downloads-menu.png'
  }.freeze

  def initialize(argv = [])
    @execution_evidence_path = nil
    parse_options!(argv.dup)
    @started_at = Time.now.utc
    @run_id = @started_at.strftime('%Y%m%dT%H%M%SZ')
    @transcript = []
    @action_results = {}
    @manifest_actions = {}
    @artifact_dir = File.join(OUTPUT_DIR, "sweep-#{@run_id}")
    @execution_evidence = nil
  end

  def run
    Dir.chdir(PROJECT_ROOT) do
      require_mini!
      FileUtils.mkdir_p(OUTPUT_DIR)
      FileUtils.mkdir_p(File.dirname(RECEIPT_PATH))
      ensure_manifest!
      verify_source_and_test_guards
      load_execution_evidence!
      write_contract_artifact
      build_action_results
      verify_all_actions_have_results!
      write_receipt
      if @execution_evidence
        puts "Customer UI execution receipt accepted: #{relative(RECEIPT_PATH)}"
      else
        puts "Customer UI contract inventory written: #{relative(RECEIPT_PATH)}"
        puts 'No app actions or clicks were executed by this script.'
      end
    end
  rescue StandardError => e
    warn "Customer UI action sweep failed: #{e.message}"
    write_failure_artifact(e)
    exit 1
  end

  private

  def parse_options!(argv)
    parser = OptionParser.new do |options|
      options.banner = 'Usage: customer_ui_action_sweep.rb [--execution-evidence PATH]'
      options.separator ''
      options.separator 'Without execution evidence, this writes a contract-only receipt.'
      options.on('--execution-evidence PATH', 'Use a separate Mini runner receipt with real per-action results') do |path|
        @execution_evidence_path = path
      end
      options.on_tail('-h', '--help', 'Show this help without changing receipts') do
        puts options
        exit 0
      end
    end
    parser.parse!(argv)
    raise OptionParser::InvalidOption, argv.join(' ') unless argv.empty?
  end

  def require_mini!
    host = Socket.gethostname.to_s.downcase
    return if host.include?('mini')
    return if air_fallback_approved?

    raise 'Customer UI action sweep must run on the Mini (Air needs SANE_APPROVE_LOCAL_UI_ON_AIR or SANE_MINI_UNAVAILABLE)'
  end

  def air_fallback_approved?
    ENV['SANE_APPROVE_LOCAL_UI_ON_AIR'] == 'MR. SANE APPROVES LOCAL UI ON AIR' ||
      ENV['SANE_MINI_UNAVAILABLE'] == 'MR. SANE CONFIRMS MINI UNAVAILABLE'
  end

  def proof_host_allowed?(host)
    normalized = host.to_s.downcase
    return true if normalized.include?('mini')
    return false unless air_fallback_approved?

    normalized.include?('air') || normalized.include?('macbook') ||
      normalized == Socket.gethostname.to_s.downcase
  end

  def ensure_manifest!
    raise "Missing #{MANIFEST_PATH}" unless File.exist?(MANIFEST_PATH)

    manifest = YAML.safe_load(File.read(MANIFEST_PATH)) || {}
    @manifest_actions = Array(manifest['actions']).each_with_object({}) do |action, memo|
      id = action['id'].to_s
      memo[id] = action unless id.empty?
    end
    @action_ids = @manifest_actions.keys
    raise 'Customer UI action manifest has no actions' if @action_ids.empty?

    missing = @action_ids - ACTION_GUARDS.keys
    extra = ACTION_GUARDS.keys - @action_ids
    raise "Sweep has no guard mapping for action(s): #{missing.join(', ')}" unless missing.empty?
    raise "Sweep has guard mapping(s) not in manifest: #{extra.join(', ')}" unless extra.empty?
  end

  def verify_source_and_test_guards
    ACTION_GUARDS.each do |action_id, guards|
      guards.each do |path, expected|
        content = read_file(path)
        raise "#{action_id}: missing #{expected.inspect} in #{path}" unless content.include?(expected)
      end
      @transcript << "source_guard=#{action_id} checks=#{guards.length}"
    end
  end

  def load_execution_evidence!
    return unless @execution_evidence_path

    path = File.expand_path(@execution_evidence_path, PROJECT_ROOT)
    payload = JSON.parse(File.read(path))
    raise 'Execution evidence app does not match SaneClick' unless payload['app'].to_s == APP_NAME
    raise 'Execution evidence must come from the Mini' unless proof_host_allowed?(payload['host'])
    raise 'Execution evidence status must be passed' unless payload['status'].to_s == 'passed'
    raise 'Execution evidence must declare execution_mode=executed' unless payload['execution_mode'].to_s == 'executed'
    Time.parse(payload.fetch('generated_at'))

    results = payload['action_results']
    raise 'Execution evidence is missing per-action results' unless results.is_a?(Hash)
    missing = @action_ids - results.keys.map(&:to_s)
    extra = results.keys.map(&:to_s) - @action_ids
    raise "Execution evidence misses action(s): #{missing.join(', ')}" unless missing.empty?
    raise "Execution evidence has unknown action(s): #{extra.join(', ')}" unless extra.empty?

    @action_ids.each do |action_id|
      result = results.fetch(action_id)
      raise "#{action_id}: execution status must be passed" unless result['status'].to_s == 'passed'
      raise "#{action_id}: workflow must declare executed=true" unless result.dig('workflow', 'executed') == true
      raise "#{action_id}: execution evidence is empty" if Array(result['evidence']).empty?
    end

    screenshots = Array(payload['screenshots'])
    raise 'Execution evidence has no screenshots' if screenshots.empty?
    missing_screenshots = screenshots.reject { |item| File.size?(File.expand_path(item, PROJECT_ROOT)) }
    raise "Execution evidence screenshot missing: #{missing_screenshots.join(', ')}" unless missing_screenshots.empty?

    @execution_evidence = payload
    @execution_evidence['source_path'] = relative(path)
  end

  def write_contract_artifact
    FileUtils.mkdir_p(@artifact_dir)
    payload = {
      generated_at: @started_at.iso8601,
      host: 'mini',
      app: APP_NAME,
      runner: relative(__FILE__),
      evidence_mode: 'contract_only',
      claim_boundary: 'This file lists planned interactions and expected outputs. It does not prove that any action or click ran.',
      actions: @action_ids.map do |action_id|
        action = @manifest_actions.fetch(action_id)
        {
          id: action_id,
          surfaces: Array(action['surfaces']),
          steps_planned: Array(action['steps']),
          inputs_planned: Array(action['user_inputs']),
          expected_outputs: Array(action['expected_outputs']),
          artifact_reference: existing_artifact_for(action_id)
        }
      end
    }
    @contract_artifact = write_json_artifact('contract-inventory.json', payload)
  end

  def build_action_results
    if @execution_evidence
      @action_results = @execution_evidence.fetch('action_results')
      return
    end

    @action_ids.each do |action_id|
      action = @manifest_actions.fetch(action_id)
      evidence_items = [
        evidence('source_guard', "#{ACTION_GUARDS.fetch(action_id).length} source/test markers are present on the Mini")
      ]
      if (artifact = existing_artifact_for(action_id))
        evidence_items << evidence(
          'artifact_reference',
          'Existing file reference only; this script did not capture or validate it as current runtime proof.',
          path: artifact
        )
      end
      @action_results[action_id] = {
        status: 'contract_only',
        required_proof_level: action.fetch('required_proof_level'),
        functional_state: {
          status: 'planned',
          detail: functional_state_detail(action)
        },
        inputs_planned: Array(action['user_inputs']),
        output_assertions_planned: Array(action['expected_outputs']),
        workflow: {
          runner: relative(__FILE__),
          executed: false,
          outcome: 'Contract and source guards checked; no app action or click was executed.',
          steps_planned: Array(action['steps']),
          steps_completed: []
        },
        evidence: evidence_items
      }
    end
  end

  def existing_artifact_for(action_id)
    path = ARTIFACT_REFERENCES[action_id]
    path if path && File.size?(path)
  end

  def functional_state_detail(action)
    state = action['functional_state'] || {}
    setup = Array(state['setup_steps']).join(' ')
    fixtures = Array(state['fixture_paths']).join(', ')
    [state['description'], setup, fixtures].compact.join(' ')
  end

  def verify_all_actions_have_results!
    missing = @action_ids - @action_results.keys.map(&:to_s)
    extra = @action_results.keys.map(&:to_s) - @action_ids
    raise "Missing action result(s): #{missing.join(', ')}" unless missing.empty?
    raise "Unexpected action result(s): #{extra.join(', ')}" unless extra.empty?
  end

  def write_receipt
    report = customer_ui_contract_report_before_receipt
    receipt = {
      app: APP_NAME,
      host: @execution_evidence ? @execution_evidence.fetch('host') : 'mini',
      generated_at: @execution_evidence ? @execution_evidence.fetch('generated_at') : @started_at.iso8601,
      manifest_sha256: report.fetch('manifest_sha256'),
      source_fingerprint: report.fetch('source_fingerprint'),
      action_results: @action_results,
      evidence: @transcript,
      contract_artifact: @contract_artifact
    }

    if @execution_evidence
      receipt.merge!(
        status: 'passed',
        execution_mode: 'executed',
        execution_source: @execution_evidence.fetch('source_path'),
        tested_action_ids: @action_ids,
        screenshots: Array(@execution_evidence['screenshots'])
      )
    else
      receipt.merge!(
        status: 'contract_only',
        execution_mode: 'not_executed',
        claim_boundary: 'Manifest, source, and test contracts only. No app actions or clicks ran.',
        contract_action_ids: @action_ids,
        tested_action_ids: [],
        screenshots: []
      )
    end

    File.write(RECEIPT_PATH, "#{JSON.pretty_generate(receipt)}\n")
    File.write(MIRROR_RECEIPT_PATH, "#{JSON.pretty_generate(receipt)}\n")
  end

  def customer_ui_contract_report_before_receipt
    out, status = Open3.capture2e(
      { 'SANEMASTER_SUPPRESS_WORKFLOW_RECEIPT' => '1' },
      SANEMASTER, 'customer_ui_contract', '--json', '--no-exit'
    )
    raise "customer_ui_contract failed before receipt write: #{out}" unless status.success?

    JSON.parse(out)
  end

  def write_failure_artifact(error)
    FileUtils.mkdir_p(OUTPUT_DIR)
    path = File.join(OUTPUT_DIR, "customer-ui-action-sweep-failure-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}.json")
    File.write(
      path,
      "#{JSON.pretty_generate(app: APP_NAME, status: 'failed', host: Socket.gethostname, generated_at: Time.now.utc.iso8601, error: error.message, transcript: @transcript)}\n"
    )
  rescue StandardError
    nil
  end

  def read_file(path)
    candidates = [
      File.join(PROJECT_ROOT, path),
      File.join(PROJECT_ROOT, '..', '..', path)
    ]
    file = candidates.find { |candidate| File.file?(candidate) }
    raise "Missing guard file #{path}" unless file

    File.read(file)
  end

  def write_json_artifact(name, payload)
    path = File.join(@artifact_dir, name)
    File.write(path, "#{JSON.pretty_generate(payload)}\n")
    relative(path)
  end

  def evidence(type, detail, path: nil)
    item = { type: type, detail: detail }
    item[:path] = path if path
    item
  end

  def relative(path)
    path.sub("#{PROJECT_ROOT}/", '')
  end
end

CustomerUIActionSweep.new(ARGV).run if __FILE__ == $PROGRAM_NAME
