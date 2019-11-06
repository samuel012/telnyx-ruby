# frozen_string_literal: true

require_relative "../test_helper"
require "securerandom"

module Telnyx
  class CallTest < Test::Unit::TestCase
    setup do
      @call = create_call
    end

    context "call instance" do
      should "be correct class" do
        assert create_call.is_a? Telnyx::Call
      end

      should "be initialized with data" do
        refute_nil @call.call_control_id
        refute_nil @call.call_leg_id
        refute_nil @call.call_session_id
        refute_nil @call.is_alive
        refute_nil @call.record_type
      end

      should "have generated instance methods methods" do
        assert defined? @call.reject
        assert defined? @call.answer
        assert defined? @call.hangup
        assert defined? @call.bridge
        assert defined? @call.speak
        assert defined? @call.fork_start
        assert defined? @call.fork_stop
        assert defined? @call.gather_using_audio
        assert defined? @call.gather_using_speak
        assert defined? @call.playback_start
        assert defined? @call.playback_stop
        assert defined? @call.record_start
        assert defined? @call.record_stop
        assert defined? @call.send_dtmf
        assert defined? @call.transfer
      end
    end

    should "retrieve call" do
      Telnyx::Call.retrieve("1234")
    end

    context "object created through #new" do
      should "get and set call_control_id through alias" do
        call = Call.new
        refute call.id
        call.id = "123"
        assert_equal "123", call.id
      end

      should "have initialize_object accessors" do
        call = Call.new
        call.id = SecureRandom.base64(20)
        call.call_leg_id = SecureRandom.base64(20)
        call.call_session_id = SecureRandom.base64(20)

        assert call.id
        assert call.call_leg_id
        assert call.call_session_id
      end

      should "send all commands" do
        @call = Call.new
        @call.id = "1234"
        @call.reject
        assert_requested :post, format_url(@call, "reject")
        @call.answer
        assert_requested :post, format_url(@call, "answer")
        @call.hangup
        assert_requested :post, format_url(@call, "hangup")
        @call.bridge call_control_id: SecureRandom.base64(20)
        assert_requested :post, format_url(@call, "bridge")
        @call.speak language: "en-US", voice: "female", payload: "Telnyx call control test"
        assert_requested :post, format_url(@call, "speak")
        @call.fork_start call_control_id: SecureRandom.base64(20)
        assert_requested :post, format_url(@call, "fork_start")
        @call.fork_stop
        assert_requested :post, format_url(@call, "fork_stop")
        @call.gather_using_audio audio_url: "https://audio.example.com"
        assert_requested :post, format_url(@call, "gather_using_audio")
        @call.gather_using_speak language: "en-US", voice: "female", payload: "Telnyx call control test"
        assert_requested :post, format_url(@call, "gather_using_speak")
        @call.playback_start audio_url: "https://audio.example.com"
        assert_requested :post, format_url(@call, "playback_start")
        @call.playback_stop
        assert_requested :post, format_url(@call, "playback_stop")
        @call.send_dtmf digits: "1www2WABCDw9"
        assert_requested :post, format_url(@call, "send_dtmf")
        @call.transfer to: "+15552223333"
        assert_requested :post, format_url(@call, "transfer")
      end
    end

    context "commands" do
      should "reject" do
        @call.reject
        assert_requested :post, format_url(@call, "reject")
      end
      should "answer" do
        @call.answer
        assert_requested :post, format_url(@call, "answer")
      end
      should "hangup" do
        @call.hangup
        assert_requested :post, format_url(@call, "hangup")
      end
      should "bridge" do
        @call.bridge call_control_id: SecureRandom.base64(20)
        assert_requested :post, format_url(@call, "bridge")
      end
      should "speak" do
        @call.speak language: "en-US", voice: "female", payload: "Telnyx call control test"
        assert_requested :post, format_url(@call, "speak")
      end
      should "start fork" do
        @call.fork_start call_control_id: SecureRandom.base64(20)
        assert_requested :post, format_url(@call, "fork_start")
      end
      should "stop fork" do
        @call.fork_stop
        assert_requested :post, format_url(@call, "fork_stop")
      end
      should "gather using audio" do
        @call.gather_using_audio audio_url: "https://audio.example.com"
        assert_requested :post, format_url(@call, "gather_using_audio")
      end
      should "gather using speak" do
        @call.gather_using_speak language: "en-US", voice: "female", payload: "Telnyx call control test"
        assert_requested :post, format_url(@call, "gather_using_speak")
      end
      should "playback start" do
        @call.playback_start audio_url: "https://audio.example.com"
        assert_requested :post, format_url(@call, "playback_start")
      end
      should "playback stop" do
        @call.playback_stop
        assert_requested :post, format_url(@call, "playback_stop")
      end
      should "send dtmf" do
        @call.send_dtmf digits: "1www2WABCDw9"
        assert_requested :post, format_url(@call, "send_dtmf")
      end
      should "transfer" do
        @call.transfer to: "+15552223333"
        assert_requested :post, format_url(@call, "transfer")
      end
    end

    context "hook handler" do
      should "register new hook event" do
        call = create_call
        call.id = nil
        ccid = SecureRandom.base64(20)
        event = make_webhook_response
        event[:event_type] = "call.answered"
        event[:payload][:call_control_id] = ccid
        event_object = TelnyxObject.construct_from(event)

        Telnyx::Call.parse_and_enqueue(event.to_json)
        assert_equal 1, call.call_hook_list.length
        assert_equal event_object, call.call_hook_list.first
        assert_equal event_object.payload.call_control_id, call.id
        call.cleanup
      end

      should "call event proc" do
        call = create_call
        ccid = SecureRandom.base64(20)
        event = make_webhook_response
        event[:event_type] = "call.answered"
        event[:payload][:call_control_id] = ccid
        event_object = TelnyxObject.construct_from(event)

        block_called = false
        call.on_hook("call.answered") do |e|
          block_called = true
          assert_equal e, event_object
        end
        call.on_hook("call.foobar") do |_e|
          assert false, "this block should not execute"
        end
        Telnyx::Call.parse_and_enqueue(event.to_json)

        assert block_called
        call.cleanup
      end

      should "call and override default event, and call global event proc" do
        call = create_call
        ccid = SecureRandom.base64(20)
        event = make_webhook_response
        event[:event_type] = "call.answered"
        event[:payload][:call_control_id] = ccid

        last_called_by = "none"
        call.on_uncaught_hook do
          last_called_by = "default"
        end
        Telnyx::Call.parse_and_enqueue(event.to_json)
        assert_equal "default", last_called_by

        last_called_by = "none"
        event_call_count = 0
        call.on_hook("call.answered") do
          event_call_count += 1
          last_called_by = "event handler"
        end
        Telnyx::Call.parse_and_enqueue(event.to_json)
        assert_equal "event handler", last_called_by

        global_called = false
        call.on_any_hook do
          global_called = true
          last_called_by = "global"
        end
        Telnyx::Call.parse_and_enqueue(event.to_json)
        assert_equal "global", last_called_by
        assert_equal 2, event_call_count
        assert global_called
        call.cleanup
      end
    end

    def create_call
      Telnyx::Call.create connection_id: "1234", to: "+15550001111", from: "+15550002222"
    end

    def format_url(call, action)
      "#{Telnyx.api_base}/v2/calls/#{call.call_control_id}/actions/#{action}"
    end
  end
end