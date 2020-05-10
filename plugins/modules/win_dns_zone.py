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
      - Specifies the type of DNS zone.
      - Secondary DNS zones will attempt to perform a zone transfer
        from a master server l(dns_servers) immediately after being 
        added.
    type: str
    default: primary
    choices: [ primary, secondary, stub, forwarder ]
  dynamic_update:
    description:
      - Specifies how a zone accepts dynamic updates.
    type: str
    choices: [ secure, none, nonsecureandsecure ]
  state:
    description:
      - Specifies the desired state of the DNS zone.
    type: str
    default: present
    choices: [ present, absent ]
  forwarder_timeout:
    description:
      - Specifies a length of time, in seconds, that a DNS server 
        waits for a master server to resolve a query.
      - Accepts values between 0 and 15.
    type: int
  replication:
    description:
      - Specifies the replication scope for the DNS zone.
      - Setting l(replication=none) disables AD replication and creates 
        a zone file with the name of the zone.
      - This is the equivalent of checking l(store the zone in Active 
        Directory) in the GUI.
      - Required when l(state=present)
    type: str
    choices: [ forest, domain, legacy, none ]
  dns_servers:
    description:
      - Specifies an list of IP addresses of the master servers of the zone.
      - Required if l(type=secondary), l(type=forwarder) or l(type=stub), otherwise ignored.
    type: list
    alias: master_servers
author:
- Joseph Zollo (@joezollo)
'''

EXAMPLES = r'''
- name: Ensure primary zone is present
  win_dns_zone:
    name: wpinner.euc.vmware.com
    replication: domain
    type: primary
    state: present

- name: Ensure DNS zone is absent
  win_dns_zone:
    name: jamals.euc.vmware.com
    state: absent

- name: Ensure forwarder has specific DNS servers
  win_dns_zone:
    name: jamals.euc.vmware.com
    type: forwarder
    dns_servers:
      - 10.245.51.100
      - 10.245.51.101
      - 10.245.51.102

- name: Ensure stub zone has specific DNS servers
  win_dns_zone:
    name: virajp.euc.vmware.com
    type: stub
    dns_servers:
      - 10.58.2.100
      - 10.58.2.101

- name: Ensure stub zone is converted to a secondary zone
  win_dns_zone:
    name: virajp.euc.vmware.com
    type: secondary

- name: Ensure secondary zone is present with no replication
  win_dns_zone:
    name: dgemzer.euc.vmware.com
    type: secondary
    replication: none
    dns_servers:
      - 10.19.20.1

- name: Ensure secondary zone is converted to a primary zone
  win_dns_zone:
    name: dgemzer.euc.vmware.com
    type: primary
    replication: none
    dns_servers:
      - 10.19.20.1

- name: Ensure primary DNS zone is present without replication
  win_dns_zone:
    name: basavaraju.euc.vmware.com
    replication: none
    type: primary

- name: Ensure DNS zone is absent
  win_dns_zone:
    name: marshallb.euc.vmware.com
    state: absent

- name: Ensure DNS zones are absent
  win_dns_zone:
    name: "{{ item }}"
    state: absent
  loop:
    - jamals.euc.vmware.com
    - dgemzer.euc.vmware.com
    - wpinner.euc.vmware.com
    - marshallb.euc.vmware.com
    - basavaraju.euc.vmware.com
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
    reverse_lookup:
    forwarder_timeout: 
    paused:
    shutdown: 
    zone_file:
    replication:
    dns_servers:
'''