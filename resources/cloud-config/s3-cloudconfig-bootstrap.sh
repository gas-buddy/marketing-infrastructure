#!/bin/bash -e

# Initilize variables
init_vars() {
  # Get instance auth token from meta-data
  instanceProfile=$(curl -s http://169.254.169.254/latest/meta-data/iam/info \
        | jq -r '.InstanceProfileArn' \
        | sed  's#.*instance-profile/##')
  roleProfile=${instanceProfile}
  accountId=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .'accountId')

  # Bucket  
  bucket=${accountId}-CLUSTER-NAME-cloudinit

  # Path to cloud-config.yaml. e.g. worker/cloud-config.yaml
  cloudConfigYaml="${roleProfile}/cloud-config.yaml"

  # Path to initial-cluster urls file to join cluster
  initialCluster="etcd/initial-cluster"

  workDir="/root/cloudinit"
  mkdir -m 700 -p ${workDir}
}

source /etc/environment

# Initlize varables
init_vars

toolbox dnf install -y awscli

cd ${workDir}

toolbox aws s3 cp "s3://${bucket}/${cloudConfigYaml}" /media/root/${workDir}
sed -i.bak "s/\\$private_ipv4/$private_ipv4/g; s/\\$public_ipv4/$public_ipv4/g; s/role=INSTANCE_PROFILE/role=$instanceProfile/g" ${workDir}/cloud-config.yaml

toolbox aws s3 cp "s3://${bucket}/${initialCluster}" /media/root/${workDir}
if [[ -f ${workDir}/initial-cluster ]] && grep -q 'ETCD_INITIAL_CLUSTER' ${workDir}/initial-cluster ;
then
  mkdir -p /etc/sysconfig
  cp ${workDir}/initial-cluster /etc/sysconfig/initial-cluster
fi

# Create /etc/environment file so the cloud-init can get IP addresses
coreos_env='/etc/environment'
if [ ! -f $coreos_env ];
then
    echo "COREOS_PRIVATE_IPV4=$private_ipv4" > /etc/environment
    echo "COREOS_PUBLIC_IPV4=$public_ipv4" >> /etc/environment
    echo "INSTANCE_PROFILE=$instanceProfile" >> /etc/environment
fi

# Run cloud-init
coreos-cloudinit --from-file=${workDir}/cloud-config.yaml
