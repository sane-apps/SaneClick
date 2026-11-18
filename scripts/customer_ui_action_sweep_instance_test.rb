#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'customer_ui_action_sweep'

# The customer UI sweep launches one SaneClick before this runner starts (18 Nov 2026: the old
# rule refused even that one, so the sweep could never pass).
class SaneClickSweepInstanceTest < Minitest::Test
  def test_none_or_the_launched_app_is_fine
    assert_nil SaneClickCustomerUIActionSweep.competing_instance_error(0)
    assert_nil SaneClickCustomerUIActionSweep.competing_instance_error(1)
  end

  def test_duplicate_instances_are_refused
    assert_match(/2 SaneClick instances running/, SaneClickCustomerUIActionSweep.competing_instance_error(2))
  end
end
