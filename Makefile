# ===========================================================================
#  BADASS - everything is driven from here.
#
#  On the host (where the Vagrantfile is):
#      make up          build/boot the VM, a VirtualBox window opens on GNS3
#      make gui         re-open the VM window
#      make ssh         shell inside the VM
#      make p1          run the part 1 checks inside the VM (no GUI needed)
#      make halt        / make destroy
#
#  Inside the VM you can call the lab directly:
#      sudo /badass/lab/run.sh test p1
# ===========================================================================
VM      ?= badass
VAGRANT ?= vagrant

.PHONY: up gui ssh halt destroy reload provision images p1 p2 p2m p3 lab-down ps clean export-p1 export-p2 export-p3 export-all gns3-project

up:
	$(VAGRANT) up

gui:
	VBoxManage startvm $(VM) --type gui

ssh:
	$(VAGRANT) ssh

halt:
	$(VAGRANT) halt

destroy:
	$(VAGRANT) destroy -f

reload:
	$(VAGRANT) reload --provision

## rebuild only the docker images inside the VM
images:
	$(VAGRANT) provision --provision-with images

## re-register GNS3 templates + the P1 project inside the VM
gns3-project:
	$(VAGRANT) provision --provision-with p1

## ---------------------------------------------------------------- the lab --
p1:
	$(VAGRANT) ssh -c 'sudo /badass/lab/run.sh test p1'

p2 p2m p3:
	$(VAGRANT) ssh -c 'sudo /badass/lab/run.sh test $@'

ps:
	$(VAGRANT) ssh -c 'sudo /badass/lab/run.sh ps'

lab-down:
	$(VAGRANT) ssh -c 'sudo /badass/lab/run.sh down'

export-p1:
	$(VAGRANT) ssh -c 'python3 /badass/tools/portable.py export P1'

export-p2:
	$(VAGRANT) ssh -c 'python3 /badass/tools/portable.py export P2 P2-multicast'

export-p3:
	$(VAGRANT) ssh -c 'python3 /badass/tools/portable.py export P3'

export-all:
	$(VAGRANT) ssh -c 'python3 /badass/tools/portable.py export P1 P2 P2-multicast P3'
