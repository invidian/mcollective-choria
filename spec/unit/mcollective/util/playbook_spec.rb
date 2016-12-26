require "spec_helper"
require "mcollective/util/playbook"

module MCollective
  module Util
    describe Playbook do
      let(:playbook) { Playbook.new }
      let(:nodes) { playbook.instance_variable_get("@nodes") }
      let(:tasks) { playbook.instance_variable_get("@tasks") }
      let(:uses) { playbook.instance_variable_get("@uses") }
      let(:inputs) { playbook.instance_variable_get("@inputs") }
      let(:playbook_fixture) { YAML.load(File.read("spec/fixtures/playbooks/playbook.yaml")) }

      describe "#seconds_to_human" do
        it "should correctly convert seconds" do
          expect(playbook.seconds_to_human(60 * 60 * 24 + (60 * 61 + 1))).to eq("1 day 1 hours 1 minutes 01 seconds")
          expect(playbook.seconds_to_human(60 * 60 * 12 + (60 * 61 + 1))).to eq("13 hours 1 minutes 01 seconds")
          expect(playbook.seconds_to_human(61)).to eq("1 minutes 01 seconds")
        end
      end

      describe "#in_context" do
        it "should set and restore context" do
          playbook.context = "rspec"
          playbook.in_context("foo") do
            expect(playbook.context).to eq("foo")
          end

          expect(playbook.context).to eq("rspec")
        end
      end

      describe "#add_cli_options" do
        it "should delegate to inputs" do
          inputs.expects(:add_cli_options).with(app = stub, true)
          playbook.add_cli_options(app, true)
        end
      end

      describe "#input_value" do
        it "should delegate to inputs" do
          inputs.expects(:[]).with("rspec").returns("rspec value")
          expect(playbook.input_value("rspec")).to eq("rspec value")
        end
      end

      describe "#discovered_nodes" do
        it "should delegate to nodes" do
          nodes.expects(:[]).with("rspec").returns(["rspec"])
          expect(playbook.discovered_nodes("rspec")).to eq(["rspec"])
        end
      end

      describe "#metadata_item" do
        it "should get the right data" do
          playbook.from_hash(playbook_fixture)
          expect(playbook.metadata_item("name")).to eq("test_playbook")
        end

        it "should fail for unknown metadata" do
          expect { playbook.metadata_item("rspec") }.to raise_error("Unknown playbook metadata rspec")
        end
      end

      describe "#validate_agents" do
        it "should pass on the data to uses" do
          uses.expects(:validate_agents).with("rpcutil" => ["rspec1"])
          playbook.validate_agents("rpcutil" => ["rspec1"])
        end
      end

      describe "#prepare_tasks" do
        it "should prepare nodes with the right data" do
          playbook.from_hash(playbook_fixture)
          tasks.expects(:from_hash).with(playbook_fixture["tasks"])
          tasks.expects(:from_hash).with(playbook_fixture["hooks"])
          tasks.expects(:prepare)
          playbook.prepare_tasks
        end
      end

      describe "#prepare_nodes" do
        it "should prepare nodes with the right data" do
          playbook.from_hash(playbook_fixture)
          playbook.expects(:t).with(playbook_fixture["nodes"]).returns(playbook_fixture["nodes"])
          nodes.expects(:from_hash).with(playbook_fixture["nodes"]).returns(nodes)
          nodes.expects(:prepare)
          playbook.prepare_nodes
        end
      end

      describe "#prepare_uses" do
        it "should prepare uses with the right data" do
          playbook.from_hash(playbook_fixture)
          playbook.expects(:t).with(playbook_fixture["uses"]).returns(playbook_fixture["uses"])
          uses.expects(:from_hash).with(playbook_fixture["uses"]).returns(uses)
          uses.expects(:prepare)
          playbook.prepare_uses
        end
      end

      describe "#prepare_inputs" do
        it "should prepare inputs with the right data" do
          playbook.input_data = {"rspec" => true}
          inputs.expects(:prepare).with("rspec" => true)
          playbook.prepare_inputs
        end
      end

      describe "#loglevel" do
        it "should report the correct loglevel" do
          expect(playbook.loglevel).to eq("info")
          expect(Playbook.new("error").loglevel).to eq("error")
          playbook.from_hash(playbook_fixture)
          expect(playbook.loglevel).to eq("debug")
        end
      end

      describe "#version" do
        it "should report the correct version" do
          playbook.from_hash(playbook_fixture)
          expect(playbook.version).to eq("1.1.2")
        end
      end

      describe "#name" do
        it "should report the correct name" do
          playbook.from_hash(playbook_fixture)
          expect(playbook.name).to eq("test_playbook")
        end
      end

      describe "#run!" do
        it "should prepare and run the tasks" do
          seq = sequence(:run)
          playbook.expects(:prepare).in_sequence(seq)
          tasks.expects(:run).in_sequence(seq).returns(:rspec_test)

          expect(playbook.run!({})).to eq(:rspec_test)
        end
      end

      describe "#prepare" do
        it "should prepare in the right order" do
          seq = sequence(:prep)
          playbook.expects(:prepare_inputs).in_sequence(seq)
          playbook.expects(:prepare_uses).in_sequence(seq)
          playbook.expects(:prepare_nodes).in_sequence(seq)
          playbook.expects(:prepare_tasks).in_sequence(seq)
          playbook.prepare
        end
      end

      describe "#from_hash" do
        it "should load the metadata, setup logger and load the inputs" do
          playbook.expects(:set_logger_level)
          inputs.expects(:from_hash).with(playbook_fixture["inputs"])

          playbook.from_hash(playbook_fixture)

          expect(playbook.metadata).to eq(
            "name" => "test_playbook",
            "version" => "1.1.2",
            "author" => "R.I.Pienaar <rip@devco.net>",
            "description" => "test description",
            "tags" => ["test"],
            "on_fail" => "fail",
            "loglevel" => "debug",
            "run_as" => "deployer.bob"
          )
        end
      end
    end
  end
end