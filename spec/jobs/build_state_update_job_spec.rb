require 'spec_helper'

describe BuildStateUpdateJob do
  let(:project) { Factory.create(:big_rails_project, :repository => repository, :name => name) }
  let(:repository) { Factory.create(:repository)}
  let(:build) { Factory.create(:build, :state => :runnable, :project => project) }
  let(:name) { repository.repository_name + "_pull_requests" }
  let(:current_repo_master) { build.ref }

  before do
    build.build_parts.create!(:kind => :spec, :paths => ["foo", "bar"])
    build.build_parts.create!(:kind => :cucumber, :paths => ["baz"])
    GitRepo.stub(:run!)
    GitRepo.stub(:current_master_ref).and_return(current_repo_master)
    BuildStrategy.stub(:promote_build)
    stub_request(:post, /https:\/\/git\.squareup\.com\/api\/v3\/repos\/square\/kochiku\/statuses\//)
  end

  shared_examples "a non promotable state" do
    it "should not promote the build" do
      BuildStateUpdateJob.perform(build.id)
      BuildStrategy.should_not_receive(:promote_build)
    end
  end

  context "build notification emails" do
    let(:name) { repository.repository_name }
    let(:build_attempt) { build.build_parts.first.build_attempts.create!(:state => :failed) }
    it "should not send a failure email if the project has never had a successful build" do
      BuildPartMailer.should_not_receive(:build_break_email)
      build.previous_successful_build.should be_nil
      ActionMailer::Base.deliveries.should be_empty
    end

    context "for a build that has had a successful build" do
      let(:build) { FactoryGirl.create(:build, :state => :succeeded, :project => project); FactoryGirl.create(:build, :state => :runnable, :project => project) }

      it "should not send the email if the build is not completed" do
        BuildPartMailer.should_not_receive(:build_break_email)
        BuildStateUpdateJob.perform(build.id)
      end

      it "should send a fail email when the build is finished" do
        build.update_attribute(:state, :aborted)
        BuildPartMailer.should_receive(:build_break_email).and_return(OpenStruct.new(:deliver => nil))
        BuildStateUpdateJob.perform(build.id)
      end

      it "does not send a email if the project setting is disabled" do
        build.update_attribute(:state, :aborted)
        repository.update_attributes!(:send_build_failure_email => false)
        BuildPartMailer.should_not_receive(:build_break_email)
        BuildStateUpdateJob.perform(build.id)
      end

      context "for a build of a project not on master" do
        let(:project) { FactoryGirl.create(:project, :branch => "other-branch")}

        it "should not send a failure email" do
          BuildPartMailer.should_not_receive(:build_break_email)
          BuildStateUpdateJob.perform(build.id)
        end
      end
    end
  end

  describe "#perform" do
    context "when incomplete but nothing has failed" do
      before do
        build.build_parts.first.build_attempts.create!(:state => :passed)
      end

      it "should be running" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to change { build.reload.state }.from(:runnable).to(:running)
      end
    end

    context "when all parts have passed" do
      before do
        build.build_parts.each do |part|
          part.build_attempts.create!(:state => :passed)
        end
      end

      describe "checking for newer sha's after finish" do
        subject { BuildStateUpdateJob.perform(build.id) }
        it "doesn't kick off a new build for normal porjects" do
          expect { subject }.to_not change(project.builds, :count)
        end

        context "with ci project" do
          let(:name) { repository.repository_name }

          context "new sha is available" do
            let(:current_repo_master) { "new-sha" }

            it "builds when there is a new sha to build" do
              expect { subject }.to change(project.builds, :count).by(1)
              build = project.builds.last
              build.queue.should == :ci
              build.ref.should == "new-sha"
            end

            it "does not kick off a new build unless finished" do
              build.build_parts.first.create_and_enqueue_new_build_attempt!
              expect { subject }.to_not change(project.builds, :count)
            end

            it "does not kick off a new build if one is already running" do
              project.builds.create!(:ref => 'some-other-sha', :state => :partitioning, :queue => :ci, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
            end

            it "does not roll back a builds state" do
              new_build = project.builds.create!(:ref => current_repo_master, :state => :failed, :queue => :ci, :branch => 'master')
              expect { subject }.to_not change(project.builds, :count)
              new_build.reload.state.should == :failed
            end

          end

          context "no new sha" do
            it "does not build" do
              expect { subject }.to_not change(project.builds, :count)
            end
          end
        end
      end

      it "should pass the build" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to change { build.reload.state }.from(:runnable).to(:succeeded)
      end

      it "should promote the build" do
        BuildStrategy.should_receive(:promote_build).with(build.ref, build.repository)
        BuildStateUpdateJob.perform(build.id)
      end

      it "should automerge the build" do
        build.update_attributes(:auto_merge => true, :queue => :developer)
        BuildStrategy.should_receive(:merge_ref).with(build)
        BuildStateUpdateJob.perform(build.id)
      end
    end

    context "when a part has failed but some are still running" do
      before do
        build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it "should doom the build" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to change { build.reload.state }.from(:runnable).to(:doomed)
      end

      it_behaves_like "a non promotable state"
    end

    context "when all parts have run and some have failed" do
      before do
        build.build_parts.each do |part|
          part.build_attempts.create!(:state => :passed)
        end
        build.build_parts.first.build_attempts.create!(:state => :failed)
      end

      it "should fail the build" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to change { build.reload.state }.from(:runnable).to(:failed)
      end

      it_behaves_like "a non promotable state"
    end

    context "when no parts" do
      before do
        build.build_parts.destroy_all
      end

      it "should not update the state" do
        expect {
          BuildStateUpdateJob.perform(build.id)
        }.to_not change { build.reload.state }
      end

      it_behaves_like "a non promotable state"

    end
  end
end
