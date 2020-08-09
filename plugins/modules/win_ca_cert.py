#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_ca_cert
short_description: Issue Certificates from Active Directory Certificate Services
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Requests & Installs
options:
  type:
    description:
    type:
    default:
    choices: []
  request:
    description:
    type:
    default:
    choices: []
  template:
    description:
    type:
    default:
    choices: []
  subject_name:
    description:
    type:
    default:
    choices: []
  dns_name:
    description:
    type:
    default:
    choices: []
  cert_store_location:
    description:
    type:
    default:
    choices: []
'''

EXAMPLES = r'''
- name: Issue web server certificate for zollo.net
  community.windows.win_ca_cert:
    template: WebServer
    subject_name: zollo.net
    dns_name:
      - zollo.net
      - www.zollo.net
      - test.zollo.net
      - files.zollo.net
  register: dhcp

- name: Gather info on a DHCP reservation with the MAC address 00-A1-B2-C2-D4-E5
  community.windows.win_dhcp_info:
    type: reservation
    mac: 00-A1-B2-C2-D4-E5
  register: dhcp

- name: Gather info on all DHCP leases
  community.windows.win_dhcp_info:
    type: lease
  register: dhcp

- name: Gather info on all DHCP scopes
  community.windows.win_dhcp_info:
    type: scope
  register: dhcp
'''
