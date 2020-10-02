#/!/usr/bin/ruby -w

# The setup
require 'time'
require 'droplet_kit'
require 'json'

if ARGV.length != 2
    puts "Usage: do-ipchange <api-token> <droplet name>"
    exit
end

Timestamp = Time.now.utc.iso8601
Token=[ARGV[0]]
Droplet_name=[ARGV[1]]
Client = DropletKit::Client.new(access_token: Token)

# Get the ID, size and location of the droplet we are doing this on
def get_droplet_id()
  droplets = Client.droplets.all
  droplets.each do |droplet|
    if droplet.name == Droplet_name
      puts "  - Droplet id: #{droplet.id}"
      puts "  - Droplet size_slug: #{droplet.size_slug}"
      puts "  - Droplet region: #{droplet.region.slug}"
      @droplet_id = droplet.id
      @droplet_size = droplet.size_slug
      @droplet_region = droplet.region.slug
    end
  end
rescue NoMethodError
  puts JSON.parse(droplets)['message']
end

# Shut down the droplet
def shutdown(id)
  res = Client.droplet_actions.shutdown(droplet_id: id)
  until res.status == "completed"
    res = Client.actions.find(id: res.id)
    sleep(2)
  end
  puts " *   Action status: #{res.status}"
rescue NoMethodError
  puts JSON.parse(res)['message']
end

# Create snapshot
def take_snapshot(id, name)
  res = Client.droplet_actions.snapshot(droplet_id: id, name: name)
  until res.status == "completed"
    res = Client.actions.find(id: res.id)
    sleep(2)
  end
  puts " *   Action status: #{res.status}"
rescue NameError
  puts JSON.parse(res)['message']
end

# Delete incumbent droplet
def delete_droplet(id)
  res = Client.droplets.delete(id: id)
  until res == True
    sleep(2)
  end
  puts " *   Action status: #{res}"
rescue NameError
  puts res
end

# Create new droplet from snapshot
def deploy_droplet()
  images = Client.images.all(public:false)
  images.each do |image|
    if image.name == Timestamp
      @image_id = image.id
      puts @image_id
    end
  end
  droplet = DropletKit::Droplet.new(name: Droplet_name, region: @droplet_region, size: @droplet_size, image: @image_id)
  res = Client.droplets.create(droplet)
  puts " *   Action status: #{res.status}"
rescue NameError
  puts JSON.parse(res)['message']
end

# Delete snapshot
def delete_snapshot()
  res = Client.images.delete(id: @image_id)
  until res == true
    sleep(2)
  end
  puts " *   Action status: #{res.status}"
rescue NameError
  puts res
end

# Get IP of new droplet
def get_IP()
    droplets = Client.droplets.all
    droplets.each do |droplet|
        if droplet.name == Droplet_name
            puts "  - Droplet id: #{droplet.id}"
            @droplet_id = droplet.id
        end
    end
    res = Client.floating_ips.find(droplet: @droplet_id)
    puts "  - Droplet IP: #{res.ip}"
rescue NameError
    puts JSON.parse(res)['message']
end

puts "Getting droplet id..."
get_droplet_id()
puts "Powering off droplet..."
shutdown(@droplet_id)
sleep(2)
puts "Taking snapshot..."
take_snapshot(@droplet_id, Timestamp)
sleep(2)
puts "Deleting droplet..."
delete_droplet(@droplet_id)
sleep(2)
puts "Creating new droplet from image..."
deploy_droplet()
sleep(2)
puts "Deleting snapshot..."
delete_snapshot()
sleep(2)
puts "Getting details of new droplet..."
get_IP()
puts " Complete"