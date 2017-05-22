cache: init_cache
	cd $(BUILD)/$@ ; $(SCRIPTS)/tf-apply-confirm.sh
	#@$(MAKE) gen_cache_vars
	@$(MAKE) get_cache_ips

# Use this for ongoing changes if you only changed cache.tf.
cache_only: init create_cache_key
	mkdir -p $(BUILD)/cache
	cp -rf $(RESOURCES)/terraforms/cache/cache.tf $(BUILD)/cache
	cd $(BUILD)/cache ; ln -sf ../*.tf .	
	cd $(BUILD)/cache ; $(SCRIPTS)/tf-apply-confirm.sh
	@$(MAKE) gen_cache_vars
	@$(MAKE) get_cache_ips

plan_cache: init_cache
	cd $(BUILD)/cache; $(TF_GET); $(TF_PLAN)

init_cache: elb etcd create_cache_key
	mkdir -p $(BUILD)/cache
	cp -rf $(RESOURCES)/terraforms/cache/cache.tf $(BUILD)/cache
	cd $(BUILD)/cache ; ln -sf ../*.tf .

destroy_cache: destroy_cache_key 
	cd $(BUILD)/cache; $(TF_DESTROY)

show_cache:  
	cd $(BUILD)/cache; $(TF_SHOW) 

create_cache_key:
	cd $(BUILD); \
		$(SCRIPTS)/aws-keypair.sh -c $(CLUSTER_NAME)-cache;

destroy_cache_key:
	cd $(BUILD); $(SCRIPTS)/aws-keypair.sh -d $(CLUSTER_NAME)-cache;

clean_cache:
	rm -rf $(BUILD)/cache $(BUILD)/cache_vars.tf

gen_cache_vars:
	cd $(BUILD)/cache; ${SCRIPTS}/gen-tf-vars.sh > $(BUILD)/cache_vars.tf

get_cache_ips:
	@echo "cache public ips: " `$(SCRIPTS)/get-ec2-public-id.sh $(CLUSTER_NAME)-cache`


# Call this explicitly to re-load user_data
update_cache_user_data:
	cd $(BUILD)/cache; \
		{TF_PLAN} -target=data.template_file.cache_cloud_config; \
		$(TF_APPLY)
		
.PHONY: cache cache_only destroy_cache plan_destroy_cache plan_cache init_cache get_cache_ips update_cache_user_data
.PHONY: show_cache create_cache_key destroy_cache_key gen_cache_vars clean_cache
