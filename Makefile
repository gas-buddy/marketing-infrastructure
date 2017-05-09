###################
## Customization ##
###################
# Change here or use environment variables, e.g. export AWS_PROFILE=<aws profile name>.

# Default SHELL for make for consistency on different platforms
SHELL := /bin/bash
# Load environments
include envs.sh

# Default AWS profile and cluster name. Please choose cluster name carefully. It will used as prefix in many AWS resources to be created.
AWS_PROFILE ?= NODEFAULT
CLUSTER_NAME ?= NODEFAULT

# Domain: default domain for Route53 zone and a self-signed *.domain cert for default ELBs.
APP_DOMAIN ?= 'example.com'

# For get-ami.sh
COREOS_UPDATE_CHANNEL ?= stable
AWS_REGION ?= us-west-2
VM_TYPE ?= hvm

# All resources used in destroy_all, in the order of dependencies.
# It doesn't hurt if a resource in the list is not created, but if it does, add 
# it to the list to make sure cleanup is done properly. 
ALL_RESOURCES := worker etcd iam s3 elb-web efs rds route53 cloudtrail vpc

# To prevent you from mistakenly using a wrong account (and end up destroying live environment),
# a list of allowed AWS account IDs should be defined:
#ALLOWED_ACCOUNT_IDS := "123456789012","012345678901"
AWS_ACCOUNT := $(shell aws --profile ${AWS_PROFILE} iam get-user | jq -r ".User.Arn" | grep -Eo '[[:digit:]]{12}')
AWS_USER := $(shell aws --profile ${AWS_PROFILE} iam get-user | jq -r ".User.UserName")
ALLOWED_ACCOUNT_IDS := "$(AWS_ACCOUNT)"

# Working Directories and files
ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT_DIR)scripts
MODULES := $(ROOT_DIR)modules
RESOURCES := $(ROOT_DIR)resources
TF_RESOURCES := $(ROOT_DIR)resources/terraforms
BUILD := $(ROOT_DIR)build-$(CLUSTER_NAME)
BUILD_SUBDIRS = $(shell [ -d $(BUILD) ] && cd $(BUILD) && ls -d */ | tr '/' ' ')
CONFIG := $(BUILD)/cloud-config
CERTS := $(BUILD)/certs
SITE_CERT := $(CERTS)/site.pem
POLICIES := $(BUILD)/policies
AMI_VAR := ami.tf

# LOCKKEY to prevent multiple terraform runs. The private key for the lock will be put in $HOME/.aws/{LOCK_KEYNAME}.pem
# which is used to valide if you own the lock.
LOCK_KEYNAME := $(CLUSTER_NAME)-tfstate-lock

# Default to confirm when applying Terraform changes to the infrastrucutre
CONFIRM_TF_APPLY ?= YES

# Terraform files
TF_PORVIDER := provider.tf
TF_DESTROY_PLAN_OUT := destroy.tfplan
TF_APPLY_PLAN := apply.tfplan
TF_STATE := terraform.tfstate

# Terraform commands
# Note: for production, set -refresh=true to be safe
TF_APPLY := terraform apply -refresh=true
# Note: for production, remove --force to confirm destroy.
TF_DESTROY := terraform destroy -force
TF_DESTROY_PLAN := terraform plan -destroy -refresh=true
TF_GET := terraform get -update
TF_GRAPH := terraform graph -module-depth=0
TF_PLAN := terraform plan -module-depth=1 -refresh=true
TF_SHOW := terraform show -module-depth=1
TF_REFRESH := terraform refresh
TF_TAINT := terraform taint -allow-missing
TF_OUTPUT := terraform output

# Comman separated list of cidr blocks to allow ssh; default to  $(curl -s http://ipinfo.io/ip)/32
# TF_VAR_allow_ssh_cidr := "$(shell curl -s http://ipinfo.io/ip)/32"
TF_VAR_timestamp := $(shell date +%Y-%m-%d-%H%M)
TF_VAR_iamuser := $(AWS_USER)

##########################
## End of customization ##
##########################

export

all: worker

help:
	@echo "Usage: make plan_<resource> | <resource> | plan_destroy_<resource> | destroy_<resource>"
	@echo "Or make show_<resource> | graph"
	@echo "Or make plan_destroy_all | destroy_all"
	@echo "Available resources: cloudtrail vault vpc s3 route53 iam efs elb etcd worker admiral rds"
	@echo "For example: make plan_worker # to show what resources are planned for worker"

lock:
	$(SCRIPTS)/session-lock.sh -l $(LOCK_KEYNAME)

unlock:
	$(SCRIPTS)/session-lock.sh -u $(LOCK_KEYNAME)

session_start: lock
	$(MAKE) pull_tf_state

session_end:
	@if ! git diff-index --name-status --exit-code HEAD -- ; then \
	    echo "You have unpublished changes:"; exit 1 ; \
	fi
	$(MAKE) push_tf_state
	$(SCRIPTS)/session-lock.sh -u $(LOCK_KEYNAME) && rm session_start

plan_destroy_all:
	@echo $(BUILD_SUBDIRS)
	@rm -rf /tmp/$(CLUSTER_NAME); mkdir -p /tmp/$(CLUSTER_NAME)
	@$(foreach resource,$(BUILD_SUBDIRS),cd $(BUILD)/$(resource) && $(TF_DESTROY_PLAN) -out /tmp/$(CLUSTER_NAME)/$(resource)-destroy.plan 2> /tmp/destroy.err;)

confirm:
	@echo "CONTINUE? [Y/N]: "; read ANSWER; \
	if [ ! "$$ANSWER" = "Y" ]; then \
		echo "Exiting." ; exit 1 ; \
    fi

destroy_all: | plan_destroy_all
	@for i in /tmp/$(CLUSTER_NAME)/*.plan; do $(TF_SHOW) $$i; done | grep -- -
	@$(eval total=$(shell for i in /tmp/$(CLUSTER_NAME)/*.plan; do $(TF_SHOW) $$i; done | grep -- - | wc -l))
	@echo ""
	@echo "Will destroy $$total resources"
	@$(MAKE) confirm
	@for i in $(ALL_RESOURCES); do \
	  if [ -d $(BUILD)/$$i ]; then \
	    $(MAKE) "destroy_$$i"; \
	  fi ; \
	done
	#rm -rf $(BUILD)

destroy: 
	@echo "Usage: make destroy_<resource> | make plan_destroy_all | make destroy_all"
	@echo "For example: make destroy_worker"
	@echo "Node: destroy may fail because of outstanding dependences"

graph: | $(BUILD)
	@mkdir -p $(BUILD)/graph
	@for i in $(ALL_RESOURCES); do \
	  if [ -d $(BUILD)/$$i ]; then \
	  	cd $(BUILD)/$$i ; \
	    $(TF_GRAPH) | dot -Tpng > $(BUILD)/graph/$$i.png ; \
	  fi ; \
	done

plan:
	@echo "plan_<resource>"

show_all:
	@$(foreach resource,$(BUILD_SUBDIRS),$(TF_SHOW) $(BUILD)/$(resource)/terraform.tfstate 2> /dev/null; )

# TODO: Push/Pull terraform states from a tf state repo
# For team work, you need to commit terraform to a remote location, such as git repo, S3 
# Should implement a locking method to prevent alter infrastructure at the same time.
pull_tf_state:
	@mkdir -p $(BUILD)
	@echo pull terraform state from ...
	#git pull --rebase 

push_tf_state:
	@echo push terraform state to ....
	#git push

# Load all resouces makefile
include resources/makefiles/*.mk

.PHONY: all confirm destroy destroy_all graph lock unlock plan_destroy_all help pull_tf_state push_tf_state
.NOTPARALLEL:

