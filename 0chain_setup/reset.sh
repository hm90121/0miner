#!/usr/bin/env bash
snap remove microk8s
snap install microk8s --classic --channel=1.17/stable
snap start microk8s
microk8s status --wait-ready
microk8s config > ~/.kube/config