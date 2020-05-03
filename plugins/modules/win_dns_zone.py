#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'metadata_version': '1.1'}

DOCUMENTATION = r'''
---
module: win_dns_zone
short_description: Manage Windows Server DNS Zones
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Manage Windows Server DNS Zones
  - Adds, Removes and Modifies DNS Zones, Forward, Stub & Reverse
  - Task should be delegated to a Windows DNS Server
options:
  name:
    description:
      - Fully qualified DNS zone name
    type: str
  type:
    description:
      - Specifies the type of DNS zone
    type: str
    default: primary
    choices: [ primary, secondary, stub, forwarder ]
  dynamic_update:
    description:
      - Specifies how a zone accepts dynamic updates.
    type: str
    default: secure
    choices: [ secure, none, nonsecureandsecure ]
  state:
    description:
      - Specifies the desired state of the DNS zone.
    type: str
    default: present
    choices: [ present, absent ]
  replication:
    description:
      - Specifies the replication scope for the DNS zone.
      - Setting l(replication=none) disables AD replication and creates a zone file with the name of the zone.
      - This is the equivalent of checking l(store the zone in Active Directory) in the GUI.
    type: str
    default: forest
    choices: [ forest, domain, legacy, none ]
  dns_servers:
    description:
      - Specifies an list of IP addresses of the master servers of the zone.
      - Required if l(type=forwarder) or l(type=stub), otherwise ignored.
    type: list
author:
- Joseph Zollo (@joezollo)
'''

EXAMPLES = r'''
- name: Ensure primary DNS zone is present
  win_dns_zone:
    name: wpinner.euc.vmware.com
    replication: domain
    type: primary
    state: present

- name: Ensure DNS zone is absent
  win_dns_zone:
    name: jamals.euc.vmware.com
    state: absent

- name: Ensure conditional forwarder has specific DNS servers
  win_dns_zone:
    name: jamals.euc.vmware.com
    type: forwarder
    dns_servers:
    - 10.245.51.100
    - 10.245.51.101
    - 10.245.51.102

- name: Ensure primary DNS zone is present without replication
  win_dns_zone:
    name: basavaraju.euc.vmware.com
    replication: none
    type: primary

- name: Ensure DNS zone is absent
  win_dns_zone:
    name: marshallb.euc.vmware.com
    state: absent
'''

RETURN = r'''
zone:
  description: New/Updated DNS zone parameters
  returned: When l(state=present)
  type: dict
  sample:
    name: 
    type: 
    dynamic_update: 
    state: 
    replication: 
    dns_servers: 
'''