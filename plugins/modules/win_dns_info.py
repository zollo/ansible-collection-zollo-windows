#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright © 2019 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# Ansible Module by Joseph Zollo (jzollo@vmware.com)

ANSIBLE_METADATA = {'status': ['preview'],
                    'supported_by': 'community',
                    'metadata_version': '1.1'}

DOCUMENTATION = r'''
---
module: win_dns_info
short_description: Gathers Info on Windows Server DNS Objects
author: Joe Zollo (@joezollo)
requirements:
  - This module requires Windows Server 2012 or Newer
description:
  - Gathers Info on Windows Server DNS Zones
  - Task should be delegated to a Windows DNS Server
options:
  type:
    description:
      - Specifies the type of DNS object to retreive
      - Specifying l(all)
    choices: [ zone, record, all ]
  zone_name:
    description:
      - Specifies the DNS zone name
    type: str
  zone_type:
    description:
      - Specifies the DNS zone type
    type: str
    default: primary
    choices: [ primary, secondary, stub, forwarder ]
  record_type:
    description:
      - Specifies the DNS record type
      - Specifying l(all) will retreive all types of records
    type: list
    default: all
    choices: [ A, AAAA, MX, CNAME, PTR, NS, TXT, all ]
  record_name:
    description:
      - Specifies the DNS record name
    type: str
    default: primary
    choices: [ primary, secondary, stub, forwarder ]
author:
- Joseph Zollo (@joezollo)
'''

EXAMPLES = r'''
- name: Gather info on all DNS records
  win_dns_info:
    type: 
    zone_name: henretty.euc.vmware.com

- name: Update/ensure DNS forwarder zone has set DNS servers
  win_dns_info:
    zone_name: shri.euc.vmware.com

'''

RETURN = r'''
zones:
  description: New/Updated DNS zone parameters
  type: dict
  sample:
    - name: sde.euc.vmware.com
      type: 
      dynamic_update: 
      state: 
      replication: 
      nameservers: 
      dns_records:
        - name: 
          fqdn: 
          type: 
          ttl: 
    - name: rds.euc.vmware.com
      type: 
      dynamic_update: 
      state: 
      replication: 
      nameservers: 
      dns_records:
        - name: 
          type: 
          ttl: 
'''