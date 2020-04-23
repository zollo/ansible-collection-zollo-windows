#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'metadata_version': '1.1'}

DOCUMENTATION = r'''
---
module: win_dhcp_scope
version_added: '2.10'
short_description: Manages Windows DHCP Server Scopes
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manages Windows DHCP Server Scopes
  - Task should be delegated to a Windows DHCP Server
options:

author:
- Joseph Zollo (@joezollo)
'''

EXAMPLES = r'''
- name: Add Scope
  win_dhcp_server_scope:
    state: present
    name: ZolloVLAN10
    active: true
    description: DHCP Server for VLAN 10
    pool_start: 192.168.100.10
    pool_end: 192.168.100.254
    subnet_mask: 255.255.255.0
    subnet_length: 24
    exclusion_list:
    subnet_delay:
    lease_duration:
    scope_options:
    - router: 192.168.100.1
      parent_domain: home.zollo.net
      dns_servers:
      - 8.8.8.8
      - 8.8.4.4

- name: 
  win_dhcp_scope:

- name: 
  win_dhcp_scope:
'''

RETURN = r'''
placeholder:
  description: x
  returned: x
  type: x
  sample: x
'''