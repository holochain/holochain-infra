#!/usr/bin/env bash

set -u

# shellcheck disable=SC2064
trap "rm $PWD/tfgrid-wg.conf" EXIT

pulumi stack -s dev output wg_access_config >tfgrid-wg.conf
nmcli connection delete tfgrid-wg
nmcli connection import type wireguard file "$PWD"/tfgrid-wg.conf
nmcli connection modify tfgrid-wg ipv4.never-default true
nmcli connection modify tfgrid-wg ipv4.routes '10.20.0.0/16'
