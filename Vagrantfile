# -*- mode: ruby -*-
# ===========================================================================
#  BADASS - the project VM.
#
#  The subject says "The entire project must be completed in a virtual
#  machine".  Instead of clicking through an installer once and hoping to
#  remember what was done, the whole machine is described here and rebuilt
#  from scratch with:
#
#       vagrant up            # build + boot, a VirtualBox window opens
#       vagrant ssh           # shell inside it
#       vagrant destroy -f    # throw it away
#
#  The VM boots straight into a graphical desktop with GNS3 running, docker
#  installed and the two project images already built.
# ===========================================================================

VM_NAME   = ENV.fetch("BADASS_VM_NAME", "badass")
VM_MEMORY = ENV.fetch("BADASS_MEMORY",  "4096").to_i
VM_CPUS   = ENV.fetch("BADASS_CPUS",    "4").to_i
# BADASS_GUI=0  ->  headless VM (the lab scripts still work over ssh)
VM_GUI    = ENV.fetch("BADASS_GUI", "1") == "1"

Vagrant.configure("2") do |config|
  config.vm.box      = "bento/ubuntu-22.04"
  config.vm.hostname = "badass"

  # the git repository itself, visible from inside the VM.  The node
  # configuration files committed in P1/ P2/ P3 are read straight from here.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/badass"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = VM_NAME
    vb.gui    = VM_GUI
    vb.memory = VM_MEMORY
    vb.cpus   = VM_CPUS
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--clipboard-mode", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
    # GNS3 can boot qemu appliances; harmless for docker-only topologies
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  config.vm.provision "base",      type: "shell", path: "provision/00-base.sh"
  config.vm.provision "docker",    type: "shell", path: "provision/10-docker.sh"
  config.vm.provision "desktop",   type: "shell", path: "provision/20-desktop.sh"
  config.vm.provision "gns3",      type: "shell", path: "provision/30-gns3.sh"
  config.vm.provision "images",    type: "shell", path: "provision/40-images.sh"
  config.vm.provision "p1",        type: "shell", path: "provision/50-p1-project.sh"

  config.vm.post_up_message = <<~MSG

    ===========================================================================
     BADASS VM is up.
       * a VirtualBox window should be showing an XFCE desktop with GNS3 open
       * ssh in with:        vagrant ssh
       * the repo lives at:  /badass   (same files as on your host)

     P1 is ready:
       - docker images  badass/host:latest  and  badass/router:latest
       - GNS3 templates "badass host" and "badass router" in the device list
       - project "P1" already contains host_pzinurov-1 and routeur_pzinurov

     Check it without the GUI:   vagrant ssh -c 'sudo /badass/lab/run.sh test p1'
    ===========================================================================
  MSG
end
