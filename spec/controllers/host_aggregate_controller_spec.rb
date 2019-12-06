describe HostAggregateController do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:aggregate) { FactoryBot.create(:host_aggregate_openstack, :ext_management_system => ems) }
  let(:host) { FactoryBot.create(:host_openstack_infra, :ext_management_system => ems) }

  before do
    EvmSpecHelper.create_guid_miq_server_zone
    login_as FactoryBot.create(:user_admin)
  end

  describe "#show" do
    subject { get :show, :params => {:id => aggregate.id} }

    context "render listnav partial" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_host_aggregate")
      end
    end
  end

  include_examples '#download_summary_pdf', :host_aggregate_openstack

  describe "#create" do
    let(:task_options) do
      {
        :action => "creating Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
        :userid => controller.current_user.userid
      }
    end
    let(:queue_options) do
      {
        :class_name  => aggregate.class.name,
        :method_name => "create_aggregate",
        :args        => [ems.id, {:name => "foo", :ems_id => ems.id.to_s }]
      }
    end

    it "builds create screen" do
      post :create, :params => { :button => "add", :format => :js, :name => 'foo', :ems_id => ems.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "queues the create action" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options))
      post :create, :params => { :button => "add", :format => :js, :name => 'foo', :ems_id => ems.id }
    end
  end

  describe "#update" do
    let(:task_options) do
      {
        :action => "updating Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
        :userid => controller.current_user.userid
      }
    end
    let(:queue_options) do
      {
        :class_name  => aggregate.class.name,
        :method_name => "update_aggregate",
        :instance_id => aggregate.id,
        :args        => [{:name => "foo"}]
      }
    end

    it "builds edit screen" do
      post :update, :params => { :button => "save", :format => :js, :id => aggregate.id, :name => "foo" }
      expect(assigns(:flash_array)).to be_nil
    end

    it "queues the update action" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options))
      post :update, :params => { :button => "save", :format => :js, :id => aggregate.id, :name => "foo" }
    end
  end

  describe "#delete_host_aggregates" do
    let(:params) { {:id => aggregate.id.to_s} }

    before { controller.params = params }

    context 'deleting Host Aggregate' do
      before { allow(controller).to receive(:redirect_to) }

      it 'calls process_host_aggregates with selected Host Aggregates' do
        expect(controller).to receive(:process_host_aggregates).with([aggregate], 'destroy')
        controller.send(:delete_host_aggregates)
      end
    end

    it 'sets flash message and redirects to show_list' do
      expect(controller).to receive(:flash_to_session)
      expect(controller).to receive(:redirect_to).with(:action => 'show_list')
      controller.send(:delete_host_aggregates)
      expect(controller.instance_variable_get(:@flash_array)).to eq([{:message => "Delete initiated for 1 Host Aggregate.", :level => :success}])
    end

    context 'Host Aggregates displayed in a nested list' do
      let(:params) { {:miq_grid_checks => aggregate.id.to_s} }

      context 'deleting selected Host Aggregates' do
        before { allow(controller).to receive(:redirect_to) }

        it 'calls process_host_aggregates with selected Host Aggregates' do
          expect(controller).to receive(:process_host_aggregates).with([aggregate], 'destroy')
          controller.send(:delete_host_aggregates)
        end
      end

      it 'sets flash message and redirects to show_list' do
        expect(controller).to receive(:flash_to_session)
        expect(controller).to receive(:redirect_to).with(:action => 'show_list')
        controller.send(:delete_host_aggregates)
        expect(controller.instance_variable_get(:@flash_array)).to eq([{:message => "Delete initiated for 1 Host Aggregate.", :level => :success}])
      end
    end
  end

  describe "#add_host" do
    let(:task_options) do
      {
        :action => "Adding Host to Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
        :userid => controller.current_user.userid
      }
    end
    let(:queue_options) do
      {
        :class_name  => aggregate.class.name,
        :method_name => "add_host",
        :instance_id => aggregate.id,
        :args        => [host.id]
      }
    end

    it "builds add host screen" do
      post :button, :params => { :pressed => "host_aggregate_add_host", :format => :js, :id => aggregate.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "queues the add host action" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options))
      post :add_host, :params => { :button => "addHost", :format => :js, :id => aggregate.id, :host_id => host.id }
    end
  end

  describe "#remove_host" do
    let(:task_options) do
      {
        :action => "Removing Host from Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
        :userid => controller.current_user.userid
      }
    end
    let(:queue_options) do
      {
        :class_name  => aggregate.class.name,
        :method_name => "remove_host",
        :instance_id => aggregate.id,
        :args        => [host.id]
      }
    end

    it "builds remove host screen" do
      post :button, :params => { :pressed => "host_aggregate_remove_host", :format => :js, :id => aggregate.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "queues the remove host action" do
      expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, hash_including(queue_options))
      post :remove_host, :params => {
        :button  => "removeHost",
        :format  => :js,
        :id      => aggregate.id,
        :host_id => host.id
      }
    end
  end
end
