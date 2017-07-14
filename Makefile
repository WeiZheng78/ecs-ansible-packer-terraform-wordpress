IMAGE:=wordpress
VERSION:=latest
SERVICE:=wordpress
ANSIBLE_ROLES_PATH:=ansible/roles
AWS_PROFILE:=default
AWS_REGION:=eu-west-1
TERRAFORM_PATH:=terraform/environments/prod
TERRARUNNER=cd $(TERRAFORM_PATH) && terraform

.PHONY: check
check:
	ansible --version
	terraform --version
	packer --version
	docker --version

.PHONY: ansible-requirements ansible-syntax-check
ansible-requirements:
	ansible-galaxy install -p $(ANSIBLE_ROLES_PATH) -r ansible/requirements.yml
ansible-syntax-check:
	ANSIBLE_ROLES_PATH=$(ANSIBLE_ROLES_PATH) ansible-playbook --syntax-check ansible/playbooks/*.yml

.PHONY: build validate
build: ansible-syntax-check
	DOCKER_REPOSITORY=`$(TERRARUNNER) output ecr_repository` IMAGE_VERSION=$(VERSION) packer build packer-wordpress.json

validate:
	packer validate ./packer-wordpress.json

.PHONY: run exec
run:
	docker run --rm -it $(IMAGE)

exec:
	docker run --rm -it $(IMAGE) bash

.PHONY: plan create-registry create-all wordpress
plan: check-env
	$(TERRARUNNER) plan

apply: check-env
	$(TERRARUNNER) apply

destroy: check-env
	$(TERRARUNNER) destroy

create-registry: check-env
	$(TERRARUNNER) apply -target=module.ecs_registry
	$(TERRARUNNER) output ecr_repository

create-all: check-env create-registry build
	$(TERRARUNNER) apply
	$(TERRARUNNER) output elb_dns

wordpress: check-env
	# $(TERRARUNNER) apply -var 'service_image_tag=$(VERSION)' -target=module.wordpress_service
	$(TERRARUNNER) apply -target=module.wordpress_service

check-env: guard-AWS_DEFAULT_PROFILE guard-AWS_DEFAULT_REGION
guard-%:
	@ if [ "${${*}}" = "" ]; then \
			echo "Environment variable $* not set"; \
			exit 1; \
	fi
