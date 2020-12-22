# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    config.vm.synced_folder ".", "/vagrant", mount_options: ["dmode=700,fmode=600"]
  else
    config.vm.synced_folder ".", "/vagrant"
  end
  config.disksize.size = '60GB'
  config.vm.define "cd" do |d| 
    d.vm.box = "ubuntu/bionic64" 
    d.vm.hostname = "cd"    
    d.vm.network "private_network", ip: "10.100.198.200"
    
    d.vm.provider "virtualbox" do |v|
      v.memory = 8096
	  v.cpus = 2
    end
  end
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
    config.vbguest.no_install = false
    config.vbguest.no_remote = false
  end
  # Install vagrant-disksize to allow resizing the vagrant box disk.
  unless Vagrant.has_plugin?("vagrant-disksize")
      raise  Vagrant::Errors::VagrantError.new, "vagrant-disksize plugin is missing. Please install it using 'vagrant plugin install vagrant-disksize' and rerun 'vagrant up'"
  end
end