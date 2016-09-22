DATABASES = Fog::Rackspace::Databases.new ({
  rackspace_username: ENV['RACKSPACE_USER'],
  rackspace_api_key: ENV['RACKSPACE_KEY'],
  rackspace_region: :lon
})

@load_balancer
@lb_ip
@restore_id

def spin_up
  db = DATABASES.instances.select { |d| d.name == INSTANCE }.first
  @tenant_id = db.links.first['href'].split('/')[4] # Such a hack

  backups_url = "https://lon.databases.api.rackspacecloud.com/v1.0/#{@tenant_id}/backups"
  backups_data = HTTParty.get backups_url, headers: { 'X-Auth-Token' => DATABASES.authenticate }
  instance_backups = backups_data['backups'].select { |bu| bu['instance_id'] == db.id }
  latest_backup = instance_backups.first['id']

  restore_db = HTTParty.post "https://lon.databases.api.rackspacecloud.com/v1.0/#{@tenant_id}/instances", headers: {
    'X-Auth-Token' => DATABASES.authenticate,
    'Content-type' => 'application/json',
    'Accept' => 'application/json'
  }, body: {
    instance: {
      flavorRef: 1,
      name: "delete-me-soon-#{DateTime.now.strftime("%Y-%m-%dT%H:%M:%S")}",
      restorePoint: {
        backupRef: latest_backup
      },
      volume: {
        size: db.volume_size
      }
    }
  }.to_json

  @restore_id = restore_db['instance']['id']

  actual_instance = DATABASES.instances.select { |s| s.id == @restore_id }.first

  print 'Waiting for DB instance '
  until actual_instance.state == 'ACTIVE' do
    print '.'
    sleep 10
    actual_instance = DATABASES.instances.select { |s| s.id == @restore_id }.first
  end

  puts ' Ready'

  change_password = HTTParty.put "https://lon.databases.api.rackspacecloud.com/v1.0/#{@tenant_id}/instances/#{@restore_id}/users", headers: {
    'X-Auth-Token' => DATABASES.authenticate,
    'Content-type' => 'application/json',
    'Accept' => 'application/json'
  }, body: {
    users: [
      {
        name: DATABASE_USER,
        password: DATABASE_PASS
      }
    ]
  }.to_json

  lb_name = "delete-me-soon-#{DateTime.now.strftime("%Y-%m-%dT%H:%M:%S")}"
  @load_balancer = HTTParty.post "https://lon.loadbalancers.api.rackspacecloud.com/v1.0/#{@tenant_id}/loadbalancers", headers: {
    'X-Auth-Token' => DATABASES.authenticate,
    'X-Project-Id' => @tenant_id,
    'Content-type' => 'application/json'
  }, body: {
    loadBalancer: {
      name: lb_name,
      port: 3306,
      protocol: "TCP",
      virtualIps: [
        {
          type: "PUBLIC"
        }
      ],
      nodes: [
        {
          address: restore_db['instance']['hostname'],
          port: 3306,
          condition: "ENABLED"
        }
      ]
    }
  }.to_json

  lb_status = HTTParty.get("https://lon.loadbalancers.api.rackspacecloud.com/v1.0/#{@tenant_id}/loadbalancers", headers: {
    'X-Auth-Token' => DATABASES.authenticate,
    'X-Project-Id' => @tenant_id
  })['loadBalancers'].select do |l|
    l['name'] =~ /delete/
  end.first['status']

  print 'Waiting for load-balancer '
  until lb_status == 'ACTIVE'
    print '.'
    lb_status = HTTParty.get("https://lon.loadbalancers.api.rackspacecloud.com/v1.0/#{@tenant_id}/loadbalancers", headers: {
      'X-Auth-Token' => DATABASES.authenticate,
      'X-Project-Id' => @tenant_id
    })['loadBalancers'].select do |l|
      l['name'] =~ /delete/
    end.first['status']
    sleep 10
  end

  puts ' Ready'

  @lb_ip = @load_balancer['loadBalancer']['virtualIps'].select { |i| i['ipVersion'] == 'IPV4' }.first['address']
  #command = "mysql -h #{@lb_ip} -u #{DATABASE_USER} -p#{DATABASE_PASS}"

  #puts command
end

def tear_down
  puts ''
  puts %{Well done. Here come the test results: "You are a horrible person." That's what it says: a horrible person. We weren't even testing for that.}
  puts ''

  lb_id = @load_balancer['loadBalancer']['id']

  print 'Deleting load-balancer... '
  HTTParty.delete("https://lon.loadbalancers.api.rackspacecloud.com/v1.0/#{@tenant_id}/loadbalancers/#{lb_id}", headers: {
    'X-Auth-Token' => DATABASES.authenticate
  })
  puts 'done'

  print 'Deleting database... '
  HTTParty.delete("https://lon.databases.api.rackspacecloud.com/v1.0/#{@tenant_id}/instances/#{@restore_id}", headers: {
    'X-Auth-Token' => DATABASES.authenticate
  })
  puts 'done'
end
