elb: vpc plan_elb
	cd $(BUILD)/elb; $(SCRIPTS)/tf-apply-confirm.sh
	@$(MAKE) get_elb_dns_name

plan_elb: plan_vpc init_elb
	cd $(BUILD)/elb; $(TF_PLAN)

destroy_elb: | $(TF_PORVIDER)
	cd $(BUILD)/elb; $(TF_DESTROY) 

plan_destroy_elb:
	cd $(BUILD)/elb; $(TF_DESTROY_PLAN)

# init elb build dir, may add init_route53 as dependence if dns registration is needed.
init_elb: | $(SITE_CERT) init #route53
	mkdir -p $(BUILD)/elb
	cp -rf $(RESOURCES)/terraforms/elb/web.tf $(BUILD)/elb
	@$(MAKE) gen_elb_vars
	cd $(BUILD)/elb; ln -sf ../*.tf .

get_elb_dns_name:
	@cd $(BUILD)/elb; elb_web_name=`$(TF_OUTPUT) elb_web_name` ; echo `$(SCRIPTS)/get-dns-name.sh $$elb_web_name`

gen_elb_vars:
	cd $(BUILD)/elb; ${SCRIPTS}/gen-tf-vars.sh > $(BUILD)/elb_vars.tf

.PHONY: elb destroy_elb plan_elb init_elb certs get_elb_dns_name plan_destroy_elb
